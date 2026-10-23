# VSBHDA
Sound blaster emulation for HDA (and AC97/SBLive); a fork of crazii's SBEMU: https://github.com/crazii/SBEMU

Works with unmodified HDPMI binaries, making it compatible with HX.

## GeosOne fork

This fork follows [Baron-von-Riedesel/VSBHDA](https://github.com/Baron-von-Riedesel/VSBHDA)
and adds:

 * **VSBVXD** (`vxd/`, `drv/`): VSBHDA for **Windows 3.1 enhanced mode**.
   `VSBVXD.386` gives DOS boxes the Sound Blaster (SB, SB Pro, SB16, OPL3 at
   388h); `VSBHDA.DRV` is the Windows wave, MIDI (OPL3 FM) and volume driver.
   No DOS components are needed for it. When Windows starts, VSBVXD unloads a
   resident DOS VSBHDA (with 386MAX, QEMM or Jemm+QPIEMU port trapping).
   Details: [vxd/VSBVXD.TXT](vxd/VSBVXD.TXT).
 * **CD audio** by PCGamingTimeMachine
   ([VSBHDARB](https://github.com/PCGamingTimeMachine/VSBHDARB)), ported to
   the current VSBHDA: digital CD audio through VSBHDA (`/CDA1`) with the
   modified SHSUCDX, see [CD audio with SHSUCDX](#cd-audio-with-shsucdx).
 * A **setup package** for the [GeosOne Dual Installer](https://github.com/geosone/gdi)
   (`install/`): it detects the memory manager (386MAX, QEMM, Jemm, HIMEM;
   setup stops without one), starts VSBHDA from AUTOEXEC.BAT with what that
   offers, installs the Windows part and sets up the MIDI Mapper.
   `INSTALL /U` removes it again.
 * Fixes: the sound card drivers (`*.DRV`) are loaded from the directory of
   `VSBHDA.EXE`; HDA acknowledges the RIRB response interrupt status (a
   driver loaded after VSBHDA got stuck in QEMU).

**Download:** [Releases](https://github.com/geosone/VSBHDA/releases): the
package as a ZIP and as a 1.44 MB disk image. Run `INSTALL.EXE` in DOS or
Windows. Tested in QEMU so far (Windows for Workgroups 3.11, Intel HDA).

| Memory manager | DOS games with sound | Windows 3.1 part |
|---|---|---|
| 386MAX | real mode and 32-bit protected mode | yes, VSBHDA is unloaded at Windows start |
| QEMM | real mode and 32-bit protected mode (+ HDPMI32i) | yes, VSBHDA is unloaded at Windows start |
| Jemm | real mode and 32-bit protected mode (+ QPIEMU, JHDPMI, HDPMI32i) | no (Jemm has no enhanced mode) |
| HIMEM only | 32-bit protected mode only (HDPMI32i, `/RM0`) | yes, but VSBHDA is not started from AUTOEXEC.BAT |

### CD audio with SHSUCDX

Many CD-ROM games play their music as audio tracks. Today's drives often
have no analog audio cable to the sound card (SATA, USB, virtual drives),
so VSBHDA can play them digitally: with `/CDA1` it reads the audio sectors
and mixes them into its output (`/CV0`-`/CV9`: CD volume, default 7).

This needs **SHSUCDX with CD audio support**,
[geosone/shsucd](https://github.com/geosone/shsucd) (SHSUCDX 4.00, release
[4.00-g1](https://github.com/geosone/shsucd/releases/tag/v4.00-g1) with a
setup that puts SHSUCDX in the place of MSCDEX or NWCDEX): the SHSUCD suite
of Jason Hood with the CD audio patch of PCGamingTimeMachine (audio reads
from the drive or from a CD image in XMS) and the GeosOne changes:

 * `SHSUCDX /A:ON`: PLAY, STOP and RESUME of the games go to VSBHDA (digital)
 * `SHSUCDX /A:OFF`: the drive plays (analog cable), as without the patch
 * `SHSUCDX /A:AUTO`: digital while VSBHDA is loaded, else analog
 * `CDAUDIO [ON | OFF | AUTO]` (`CDAUDIO.COM`): shows or switches the mode
   at run time
 * API: INT 2Fh AX=15FFh BX=CDDAh (CX=0 register the player, 1 status,
   2 set mode, 3 unregister); VSBHDA unregisters itself when it is unloaded

Any CD-ROM driver works below SHSUCDX, also `ASPICDA.SYS` of
[OpenASPI](https://github.com/geosone/OpenASPI) for AHCI and USB drives:
[AHCIASPI](https://github.com/geosone/ahciaspi) and
[EUSBASPI](https://github.com/geosone/eusbaspi) 0.4 install it together with
SHSUCDX and `CDAUDIO.COM`. The setup package offers the CD audio option when it finds
SHSUCDX with CD audio loaded (`VSBCHK /CDA`) and then starts VSBHDA with
`/CDA1`. MSCDEX and the original SHSUCDX don't have the API: there the
drive plays as before.

In Windows 3.1, VSBVXD has no digital CD audio: the MCI CD audio driver
lets the drive play.

**Building the package** (Linux): `install/mkpkg.sh` builds VSBHDA, the
drivers, VSBVXD and VSBHDA.DRV, fetches HDPMI32i/JHDPMI (HX 2.23) and
JLOAD/QPIEMU (Jemm 5.86) from their releases (SHA-256 checked) and writes
`build/pkg`, `build/vsbhda.zip` and `build/VSBHDA.IMG`. `VXDLINK` must name
a JWlink with working `format windows vxd` (see vxd/VSBVXD.TXT); `GDI` names
`INSTALL.EXE` (default `../gdi/build/INSTALL.EXE`).

**Tests** (QEMU): `test/win311.sh` runs VSBVXD in Windows for Workgroups 3.11
(`MM=386max` for 386MAX), `test/install.sh` installs the package, plays a
tone in DOS and in Windows and removes it again. `make -C test/win` builds
the Windows test programs and test sounds.

## Upstream

**Supported Sound hardware:**
 * CS4281 chip by Cirrus Logic
 * ES1370 chip by Ensoniq ( AudioPCI )
 * Intel ICH, Nvidia nForce, SiS 7012
 * HDA ( Intel High Definition Audio )
 * SB based on ES1371/73 or CT5580 ( AudioPCI '97, Sound Blaster PCI 64/128 )
 * SB based on EMU10Kx ( SB Live, SB Audigy )
 * SB based on CA0106 ( Audigy LS/SE, Life 24, X-Fi Xtreme Audio [SB0790] )
 * SB based on EMU20Kx ( SB X-Fi, SB X-Fi Titanium ) 
 * VIA VT82C686, VT8233/35/37 [not VT8233A]

Fork VSBCMI (https://github.com/drivelling-spinel/VSBCMI/tree/main) also supports cards based on CMI 8338/8738.

**Emulated cards**: Sound Blaster 1.0, 2.0, Pro, Pro 2, 16.

**Requirements:**
 * HDPMI32i - DPMI host with port trapping; 32-bit protected-mode
 * HDPMI16i - DPMI host with port trapping; 16-bit protected-mode
 * JEMM386/JEMMEX - V86 monitor with port trapping; v86-mode
 * or instead of Jemm: QEMM (QPI port trapping), or 386MAX (QPI port trapping and DPMI host built in)
 
VSBHDA uses source code from:
 * MPXPlay: https://mpxplay.sourceforge.net/ - sound hardware access
 * DOSBox: https://www.dosbox.com/ - OPL3 FM emulation & ADPCM decoding
 * TinySoundFont: https://github.com/schellingb/TinySoundFont - MIDI synthesizer emulation

A few **makefiles** are supplied to create the binaries:
 * Makefile/OW16.mak/Drivers.mak: for Windows/DOS using Open Watcom (v1.9 or v2.0) and JWasm/JWlink
 * Linux.mak/Linux16.mak/LinuxDrv.mak: for Linux using Open Watcom (v1.9 or v2.0) and JWasm/JWlink
 * djgpp.mak: for DOS using DJGPP v2.05 and JWasm; cannot create the 16-bit variant of VSBHDA

Source of tools used by the makefiles:
 * JWasm (https://github.com/Baron-von-Riedesel/JWasm); must be at least v2.17
 * JWlink (https://github.com/Baron-von-Riedesel/jwlink); must be at least v2.0
 * Open Watcom v2 (https://github.com/open-watcom/open-watcom-v2/releases/tag/2024-03-01-Build)

**AI Policy:**

 With version 2.1, VSBHDA has been split in two parts: on one side the VSBHDA
 core binary (VSBHDA.EXE, VSBHDA16.EXE), on the other side external driver
 modules ( HDA.DRV, SBGEB.DRV, ... ). This separation is also reflected on the
 source code tree, with two branches ( src and srcdrv ). The AI policy differs
 for those two branches:

 * for the VSBHDA core, **no** LLM assisted/generated code is accepted.
 * for external driver modules, LLM assisted/generated code is acceptable.

