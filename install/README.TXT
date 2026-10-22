VSBHDA - Sound Blaster emulation for DOS and Windows 3.1
========================================================

What Setup did
--------------
VSB.BAT starts VSBHDA with what the memory manager offers (Setup installed
the variant for yours):

  386MAX     VSBHDA.EXE (386MAX has QPI and the DPMI host built in)
  QEMM       HDPMI32I.EXE -x2, VSBHDA.EXE
  Jemm       JLOAD QPIEMU.DLL, JLOAD JHDPMI.DLL, HDPMI32I.EXE -x2, VSBHDA.EXE
  HIMEM      HDPMI32I.EXE -x2, VSBHDA.EXE /RM0: no port trapping for
             real-mode games, only 32-bit protected-mode games have sound

AUTOEXEC.BAT sets VSBHDA= (the installation directory, used by VSB.BAT) and
BLASTER=A220 I5 D1 H5 T6 P330 (a Sound Blaster 16), and calls VSB.BAT. VSBHDA.TXT lists the options (volume
/VOL, output /O, frequency /F and more); VSB passes them on, e.g. VSB /VOL7.
UNINST.EXE unloads VSBHDA.

Windows 3.1 enhanced mode does not start while VSBHDA is loaded (VSBHDA is
a resident DPMI program). VSBVXD.386 unloads it when Windows starts, with
386MAX and QEMM; after Windows, VSB starts it again. With HIMEM only this
is not possible (VSBHDA runs without port trapping): Setup doesn't start
VSBHDA in AUTOEXEC.BAT then; start VSB before a DOS game outside Windows
and UNINST before WIN.

Windows 3.1 (enhanced mode): VSBVXD.386 ([386Enh] in SYSTEM.INI) gives the
DOS boxes the Sound Blaster, VSBHDA.DRV ([drivers] wave, midi, aux) is the
Windows driver; DOS programs in Windows need no VSB. The MIDI
Mapper setup "Ad Lib general" plays General MIDI on VSBHDA OPL3 FM; the
previous MIDIMAP.CFG is kept as MIDIMAP.VSB. VSBVXD.TXT has the details.
Jemm cannot run Windows 3.1 in enhanced mode, so Setup does not offer the
Windows part with Jemm.

Removing
--------
INSTALL /U in the installation directory removes everything again,
including the MIDI Mapper change.

Licenses
--------
VSBHDA, VSBVXD and VSBHDA.DRV: GNU General Public License 2 (LICENSE.TXT).
HDPMI32I.EXE and JHDPMI.DLL (HX runtime, Japheth): freeware (HXRT.TXT).
JLOAD.EXE and QPIEMU.DLL (Jemm, Japheth): Artistic License (ARTISTIC.TXT).
INSTALL.EXE (GeosOne Dual Installer): GNU General Public License 3.
