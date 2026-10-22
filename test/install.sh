#!/bin/bash
# Test the setup package (install/mkpkg.sh -> build/pkg) in QEMU on a
# Windows for Workgroups 3.11 hard disk:
#   boot 1: INSTALL /S from C:\PKG (defaults: DOS and Windows part)
#   boot 2: the AUTOEXEC.BAT written by setup starts VSBHDA; SBPLAY plays a
#           tone in DOS, then WIN: VSBVXD unloads VSBHDA, PLAYWAV plays
#           T440.WAV in Windows
#   boot 3: INSTALL /U removes it again (MIDIMAP.CFG back from MIDIMAP.VSB)
#
#   test/install.sh
#
# Environment:
#   WIN311IMG  hard disk image with WfW 3.11 in C:\WINDOWS (required)
#   MM         memory manager: 386max (default) or himem
#   MAXBIN     386MAX.SYS and 386MAX.VXD (default ~/mars/Open386MAX/build/bin)
#   WAV        test sound (default build/test-win/T440.WAV, make -C test/win)
#
# Output (build/test-install/): serial.log, vxd.log, sound.wav, screen.png
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/build/test-install
BASE=${WIN311IMG:?set WIN311IMG to a WfW 3.11 hard disk image}
MM=${MM:-386max}
MAXBIN=${MAXBIN:-$HOME/mars/Open386MAX/build/bin}
WAV=${WAV:-$ROOT/build/test-win/T440.WAV}
[ -f "$ROOT/build/pkg/INSTALL.EXE" ] || { echo "no build/pkg (install/mkpkg.sh)"; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/c/PKG" "$OUT/c/T" "$OUT/c/VSB"   # PLAYWAV writes C:\VSB\OUT.TXT
touch "$OUT/c/VSB/OUT.TXT"
cp "$ROOT"/build/pkg/* "$OUT/c/PKG/"
cp "$ROOT/build/test-win/PLAYWAV.EXE" "$WAV" "$OUT/c/T/"
nasm -f bin -o "$OUT/c/T/SBPLAY.COM" "$ROOT/test/dos/SBPLAY.ASM" || exit 1
printf 'org 100h\nmov dx,501h\nmov al,0\nout dx,al\nint 20h\n' > "$OUT/qexit.asm"
nasm -f bin -o "$OUT/c/QEXIT.COM" "$OUT/qexit.asm" || exit 1
cp "$BASE" "$OUT/test.img"

crlf() { tr '|' '\n' | sed 's/$/\r/'; }
case "$MM" in
himem)  MMLINE='DEVICE=C:\HIMEM.SYS|DOS=HIGH' ;;
386max) mkdir -p "$OUT/c/MAX"; cp "$MAXBIN/386MAX.SYS" "$MAXBIN/386MAX.VXD" "$OUT/c/MAX/"
        printf '; 386MAX profile\r\n' > "$OUT/c/MAX/386MAX.PRO"
        MMLINE='DEVICE=C:\MAX\386MAX.SYS PRO=C:\MAX\386MAX.PRO|DOS=HIGH,UMB' ;;
*)      echo "unknown MM=$MM" >&2; exit 1 ;;
esac
echo "$MMLINE|FILES=40|BUFFERS=20|SHELL=C:\\COMMAND.COM C:\\ /P" | crlf > "$OUT/c/CONFIG.SYS"
# setup adds its lines before the last line, WIN: C:\T\WIN.BAT runs the tests
{
    echo '@ECHO OFF'
    echo 'PATH C:\T;C:\;C:\WINDOWS'
    echo 'IF EXIST C:\VSBHDA\README.TXT GOTO TEST'   # (setup removes lines with VSB.BAT)
    echo 'ECHO --- setup > AUX'
    echo 'C:\PKG\INSTALL.EXE /S > AUX'
    echo 'ECHO --- AUTOEXEC.BAT > AUX'
    echo 'TYPE C:\AUTOEXEC.BAT > AUX'
    echo 'QEXIT'
    echo ':TEST'
    echo 'WIN'
} | crlf > "$OUT/c/AUTOEXEC.BAT"
{
    echo '@ECHO OFF'
    echo 'ECHO --- DOS: SBPLAY > AUX'
    echo 'C:\T\SBPLAY > AUX'
    echo 'ECHO --- starting Windows > AUX'
    echo 'C:\WINDOWS\WIN C:\T\PLAYWAV.EXE C:\T\T440.WAV > AUX'
    echo 'ECHO --- back from Windows > AUX'
    echo 'QEXIT'
} | crlf > "$OUT/c/T/WIN.BAT"

P="$OUT/test.img@@32256"
mcopy -o -s -i "$P" "$OUT"/c/* ::/ || exit 1
if [ "$MM" = 386max ]; then
    mcopy -o -i "$P" ::/WINDOWS/SYSTEM.INI "$OUT/system.ini"
    sed -i 's/^\[386Enh\]\r$/[386Enh]\r\ndevice=C:\\MAX\\386MAX.VXD\r/' "$OUT/system.ini"
    mcopy -o -i "$P" "$OUT/system.ini" ::/WINDOWS/SYSTEM.INI
fi

boot() {   # seconds wav n [keys after 15 s]
    {
        if [ -n "${4:-}" ]; then sleep 15; for k in $4; do echo "sendkey $k"; sleep 2; done; fi
        sleep "$1"; echo "screendump $OUT/screen$3.ppm"; sleep 1; echo quit
    } | qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m 32 -display none -vga std -monitor stdio \
        -drive if=ide,index=0,format=raw,file="$OUT/test.img" -boot c -nic none \
        -audiodev wav,id=snd0,path="$2" -device intel-hda -device hda-duplex,audiodev=snd0 \
        -serial file:"$OUT/serial$3.log" -debugcon file:"$OUT/vxd.log" \
        -device isa-debug-exit,iobase=0x501,iosize=0x02 > "$OUT/monitor$3.log" 2>&1
}
boot 60 "$OUT/setup.wav" 1
boot 100 "$OUT/sound.wav" 2
mcopy -o -i "$P" ::/WINDOWS/SYSTEM.INI "$OUT/system.ini.after"
mcopy -o -i "$P" ::/AUTOEXEC.BAT "$OUT/autoexec.after"
# boot 3: remove it
{
    echo '@ECHO OFF'
    echo 'ECHO --- INSTALL /U > AUX'
    echo 'C:\VSBHDA\INSTALL.EXE /U > AUX'
    echo 'ECHO --- AUTOEXEC.BAT > AUX'
    echo 'TYPE C:\AUTOEXEC.BAT > AUX'
    echo 'QEXIT'
} | crlf > "$OUT/c/T/WIN.BAT"
mcopy -o -i "$P" "$OUT/c/T/WIN.BAT" ::/T/
boot 20 "$OUT/uninst.wav" 3 "r ret ret"
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
tr -d '\r' < "$OUT/serial1.log"
tr -d '\r' < "$OUT/serial2.log"
echo "=== SYSTEM.INI after setup"
grep -i -E 'vsb|^wave|^midi|^aux' "$OUT/system.ini.after" | tr -d '\r'
tr -d '\r' < "$OUT/serial3.log"
echo "=== VxD log"; cat "$OUT/vxd.log"
mcopy -i "$P" ::/VSB/OUT.TXT "$OUT/out.txt" 2>/dev/null && { echo "=== OUT.TXT"; tr -d '\r' < "$OUT/out.txt"; }
echo "=== after INSTALL /U"
mcopy -o -i "$P" ::/WINDOWS/SYSTEM.INI "$OUT/system.ini.removed"
grep -i -E 'vsb|^wave=|^midi=|^aux=' "$OUT/system.ini.removed" | tr -d '\r'
mdir -i "$P" ::/VSBHDA >/dev/null 2>&1 && echo "C:\VSBHDA still there"
mdir -i "$P" ::/WINDOWS/SYSTEM/MIDIMAP.VSB >/dev/null 2>&1 && echo "MIDIMAP.VSB still there"
mdir -i "$P" ::/WINDOWS/SYSTEM/VSBVXD.386 >/dev/null 2>&1 && echo "VSBVXD.386 still there"
mcopy -o -i "$P" ::/WINDOWS/SYSTEM/MIDIMAP.CFG "$OUT/midimap.removed"
mcopy -o -i "$BASE@@32256" ::/WINDOWS/SYSTEM/MIDIMAP.CFG "$OUT/midimap.orig"
cmp -s "$OUT/midimap.removed" "$OUT/midimap.orig" && echo "MIDIMAP.CFG restored" || echo "MIDIMAP.CFG differs"
