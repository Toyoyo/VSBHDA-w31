@ECHO OFF
REM VSBHDA with HIMEM only: no port trapping, protected-mode games only
LH %VSBHDA%\HDPMI32I.EXE -x2
%VSBHDA%\VSBHDA.EXE /RM0 %1 %2 %3 %4 %5 %6
