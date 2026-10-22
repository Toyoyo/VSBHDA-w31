; VSBCHK.COM - what the computer offers VSBHDA, for the [Detect] section of
; INSTALL.INI (GeosOne Dual Installer): exit code 0 = yes, 1 = no.
;
;   VSBCHK /MAX    386MAX is loaded (QPI port trapping and the HDPMI API
;                  built in: VSBHDA needs no HDPMI, Jemm or QPIEMU)
;   VSBCHK /QEMM   QEMM is loaded (QPI port trapping, not 386MAX)
;   VSBCHK /JEMM   Jemm386 or JemmEx is loaded (port trapping with QPIEMU)
;   VSBCHK /XMS    an XMS driver (HIMEM, or one of the above)
;   VSBCHK /CDA    SHSUCDX with digital CD audio (/A:ON or /A:AUTO)
;
; nasm -f bin -o VSBCHK.COM VSBCHK.ASM

	cpu	8086
	org	100h

start:	mov	si, 81h
.skip:	lodsb
	cmp	al, ' '
	je	.skip
	cmp	al, 9
	je	.skip
	cmp	al, '/'
	jne	usage
	lodsb
	and	al, 0DFh
	cmp	al, 'M'
	je	chk_max
	cmp	al, 'Q'
	je	chk_qemm
	cmp	al, 'J'
	je	chk_jemm
	cmp	al, 'X'
	je	chk_xms
	cmp	al, 'C'
	je	chk_cda

usage:	mov	dx, msg_usage
	mov	ah, 9
	int	21h
	mov	ax, 4C02h
	int	21h

yes:	mov	ax, 4C00h
	int	21h
no:	mov	ax, 4C01h
	int	21h

; the character device 386MAX$$
chk_max:
	call	is_max
	jc	no
	jmp	yes

is_max:	mov	dx, dev_max
	call	open_chardev
	jc	.ret
	call	close
	clc
.ret:	ret

; QEMM's installation check (386MAX answers it as well)
chk_qemm:
	call	is_max
	jnc	no
	mov	ax, 0D200h
	mov	bx, 5144h
	mov	cx, 4D45h
	mov	dx, 4D30h
	int	2Fh
	cmp	al, 0FFh
	jne	no
	cmp	bx, 4D45h			; 'ME'
	jne	no
	jmp	yes

; Jemm: EMMXXXX0 (EMMQXXX0 with NOEMS), IOCTL read of 6 bytes returns
; version 0028h in the first word (as JLOAD checks it)
chk_jemm:
	mov	dx, dev_emm
	call	open_chardev
	jnc	.open
	mov	dx, dev_emmq
	call	open_chardev
	jc	no
.open:	xor	ax, ax
	mov	[ioctl_buf], ax
	mov	[ioctl_buf+2], ax
	mov	[ioctl_buf+4], ax
	mov	dx, ioctl_buf
	mov	cx, 6
	mov	ax, 4402h
	int	21h
	pushf
	call	close
	popf
	jc	no
	cmp	word [ioctl_buf], 0028h
	jne	no
	jmp	yes

chk_xms:
	mov	ax, 4300h
	int	2Fh
	cmp	al, 80h
	jne	no
	jmp	yes

; the CD audio API of SHSUCDX: status (CX=1) does not register a player
chk_cda:
	mov	ax, 15FFh
	mov	bx, 0CDDAh
	mov	cx, 1
	int	2Fh
	cmp	ax, 0CDDAh
	jne	no
	jmp	yes

; DS:DX = name: CF clear and BX = handle when it is a character device
open_chardev:
	mov	ax, 3D00h
	int	21h
	jc	.ret
	mov	bx, ax
	mov	ax, 4400h
	int	21h
	jc	.notdev
	test	dl, 80h
	jz	.notdev
	clc
.ret:	ret
.notdev:
	call	close
	stc
	ret

close:	mov	ah, 3Eh
	int	21h
	ret

dev_max		db	'386MAX$$', 0
dev_emm		db	'EMMXXXX0', 0
dev_emmq	db	'EMMQXXX0', 0
msg_usage	db	'VSBCHK /MAX | /QEMM | /JEMM | /XMS | /CDA', 13, 10
		db	'exit code 0: present, 1: not present', 13, 10, '$'
ioctl_buf	dw	0, 0, 0
