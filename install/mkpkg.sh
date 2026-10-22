#!/bin/bash
# install/mkpkg.sh - the VSBHDA package for the GeosOne Dual Installer
# (https://github.com/geosone/gdi): DOS (VSBHDA, the sound card drivers,
# HDPMI32i, JHDPMI, QPIEMU) and Windows 3.1 (VSBVXD.386, VSBHDA.DRV).
#
#   install/mkpkg.sh      -> build/pkg, build/vsbhda.zip, build/VSBHDA.IMG
#
# Environment:
#   WATCOM   Open Watcom 2.0 (default /opt/watcom)
#   VXDLINK  JWlink, one with working "format windows vxd" (vxd/VSBVXD.TXT;
#            another JWlink leaves out the BSS pages, WIN386 hangs)
#   GDI      INSTALL.EXE of the GeosOne Dual Installer
#            (default ../gdi/build/INSTALL.EXE)
#   DL       download directory (default build/dl); CACHE: a directory
#            searched first for the archives (e.g. ~/Iso/Dos)
# The HX runtime and Jemm come from their GitHub releases, checked with
# SHA-256.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export WATCOM=${WATCOM:-/opt/watcom}
VXDLINK=${VXDLINK:?set VXDLINK to the JWlink with Windows 3.x VxD support}
GDI=${GDI:-$ROOT/../gdi/build/INSTALL.EXE}
DL=${DL:-$ROOT/build/dl}
PKG=$ROOT/build/pkg

HXRT=HXRT223.zip
HXRT_URL=https://github.com/Baron-von-Riedesel/HX/releases/download/v2.23/$HXRT
HXRT_SHA=20510cf66d6c8704f66f908f8fbf9783198195c1e043a6ca9fb6adeadf8785c9
JEMM=JemmB_v586.zip
JEMM_URL=https://github.com/Baron-von-Riedesel/Jemm/releases/download/v5.86/$JEMM
JEMM_SHA=94838a1836f94d95dcf84d250f7968dfca2eb6b5cfa7ac664d6e01f22f0d296e

fetch() {   # name url sha256
    mkdir -p "$DL"
    if [ ! -f "$DL/$1" ]; then
        if [ -n "${CACHE:-}" ] && [ -f "$CACHE/$1" ]; then
            cp "$CACHE/$1" "$DL/$1"
        else
            curl -fsSL -o "$DL/$1" "$2"
        fi
    fi
    echo "$3  $DL/$1" | sha256sum -c --quiet -
}
crlf() { sed 's/\r*$/\r/' "$1" > "$2"; }

fetch $HXRT $HXRT_URL $HXRT_SHA
fetch $JEMM $JEMM_URL $JEMM_SHA

cd "$ROOT"
make -f Linux.mak LINK="$VXDLINK" >/dev/null
make -f LinuxDrv.mak LINK="$VXDLINK" >/dev/null
make -C vxd LINK="$VXDLINK" >/dev/null
make -C drv >/dev/null

rm -rf "$PKG" && mkdir -p "$PKG"
cp ow/VSBHDA.EXE owdrv/*.DRV "$PKG/"
cp build/vxd/VSBVXD.386 build/drv/VSBHDA.DRV "$PKG/"
nasm -f bin -o "$PKG/VSBCHK.COM" install/VSBCHK.ASM
nasm -f bin -o "$PKG/VSBMAP.COM" install/VSBMAP.ASM
jwasm -q -mz -Fo"$PKG/UNINST.EXE" Tools/Uninst/UNINST.ASM
unzip -q -o -j "$DL/$HXRT" BIN/HDPMI32i.EXE BIN/JHDPMI.DLL HXRT.TXT -d "$PKG/"
mv "$PKG/HDPMI32i.EXE" "$PKG/HDPMI32I.EXE"
unzip -q -o -j "$DL/$JEMM" QPIEMU.DLL JLOAD.EXE Artistic.txt -d "$PKG/"
mv "$PKG/Artistic.txt" "$PKG/ARTISTIC.TX_" && crlf "$PKG/ARTISTIC.TX_" "$PKG/ARTISTIC.TXT" && rm "$PKG/ARTISTIC.TX_"
cp install/INSTALL.INI install/VSB*.BAT drv/OEMSETUP.INF "$PKG/"
crlf install/README.TXT "$PKG/README.TXT"
crlf vsbhda.txt "$PKG/VSBHDA.TXT"
crlf vxd/VSBVXD.TXT "$PKG/VSBVXD.TXT"
crlf LICENSE "$PKG/LICENSE.TXT"
cp "$GDI" "$PKG/INSTALL.EXE"
sed -i 's/\r*$/\r/' "$PKG/INSTALL.INI"

cd "$PKG"
rm -f ../vsbhda.zip && zip -q -9 ../vsbhda.zip *
# a 1.44 MB disk (mtools), e.g. for mkdosset.ps1 -Extra of msdosinst
rm -f ../VSBHDA.IMG && mformat -C -f 1440 -v VSBHDA -i ../VSBHDA.IMG :: && mcopy -i ../VSBHDA.IMG * ::
du -sh "$PKG" ../vsbhda.zip
