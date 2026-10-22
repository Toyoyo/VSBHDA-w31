; VSBMAP.COM - the MIDI Mapper of Windows 3.1 for VSBHDA.DRV, from DOS:
; what VSBHDA.DRV does on DRV_INSTALL (drv/MIDIMAP.C), for the GeosOne
; Dual Installer ([Run] After= and Uninstall=).
;
;   VSBMAP windir      MIDIMAP.CFG: the General MIDI setup "Ad Lib general"
;                      plays all 16 channels on "VSBHDA OPL3 FM" and is the
;                      active setup; the original is kept as MIDIMAP.VSB
;   VSBMAP windir /U   MIDIMAP.VSB back to MIDIMAP.CFG
;
; MIDIMAP.CFG (windir\SYSTEM): word 0 version (1), word 6 id of the active
; setup; setup table at 48h, entries of 54 bytes: name (16), description
; (32), id, offset of the channel map, 0; channel map: 16 entries of 40
; bytes: destination channel, port name (32), patchmap id, active, 0.
;
; nasm -f bin -o VSBMAP.COM VSBMAP.ASM

	cpu	8086
	org	100h

SETUP_TABLE	equ	48h
SETUP_SIZE	equ	54
CHAN_SIZE	equ	40
MAXSIZE		equ	0FF00h

start:	; windir from the command line -> cfg_path, bak_path
	mov	si, 81h
	call	skip
	cmp	al, 0Dh
	je	usage
	mov	di, cfg_path
.copy:	lodsb
	cmp	al, ' '
	je	.end
	cmp	al, 9
	je	.end
	cmp	al, 0Dh
	je	.end
	stosb
	cmp	di, cfg_path + 100
	jb	.copy
	jmp	usage
.end:	dec	si
	cmp	byte [di-1], '\'
	jne	.sep
	dec	di
.sep:	push	si
	mov	si, s_system
	call	strcpy				; "\SYSTEM\MIDIMAP."
	mov	[ext_ofs], di
	mov	si, s_cfg
	call	strcpy
	; the backup name: the same with .VSB
	mov	si, cfg_path
	mov	di, bak_path
	call	strcpy
	mov	di, [ext_ofs]
	sub	di, cfg_path
	add	di, bak_path
	mov	si, s_vsb
	call	strcpy
	pop	si
	call	skip
	cmp	al, '/'
	jne	install
	mov	al, [si+1]
	and	al, 0DFh
	cmp	al, 'U'
	je	uninstall
	jmp	usage

install:
	; the file into a 64 KB buffer after the program
	mov	bx, 1000h
	mov	ah, 4Ah				; COM: keep 64 KB
	push	cs
	pop	es
	int	21h
	mov	bx, 1000h
	mov	ah, 48h
	int	21h
	jc	fail
	mov	[bufseg], ax
	mov	dx, cfg_path
	mov	ax, 4300h			; no MIDIMAP.CFG: nothing to do
	int	21h
	jc	nothing
	; keep the original once (MIDIMAP.VSB not there yet)
	mov	dx, bak_path
	mov	ax, 4300h
	int	21h
	jnc	.read
	mov	dx, cfg_path
	mov	si, bak_path
	call	copy_file
	jc	fail
.read:	mov	dx, cfg_path
	call	read_file			; CX = size
	jc	fail
	mov	[size], cx
	mov	es, [bufseg]
	cmp	cx, SETUP_TABLE
	jb	fail
	cmp	word [es:0], 1
	jne	fail

	; the setup "Ad Lib general"
	mov	bx, SETUP_TABLE
.next:	mov	ax, bx
	add	ax, SETUP_SIZE
	jc	notfound
	cmp	ax, [size]
	ja	notfound
	cmp	byte [es:bx], 0
	je	notfound
	mov	si, s_adlib
	mov	di, bx
	call	strcmpi_es
	je	.found
	add	bx, SETUP_SIZE
	jmp	.next
.found:	mov	di, [es:bx+50]			; the channel map
	mov	ax, di
	add	ax, 16 * CHAN_SIZE
	jc	fail
	cmp	ax, [size]
	ja	fail
	push	bx
	xor	dx, dx				; channel
.chan:	mov	[es:di], dx			; channel unchanged
	push	di
	add	di, 2
	mov	cx, 32
	xor	al, al
	push	di
	rep	stosb
	pop	di
	mov	si, s_port
.port:	lodsb
	stosb
	test	al, al
	jnz	.port
	pop	di
	mov	word [es:di+34], 0		; no patchmap
	mov	word [es:di+36], 1		; active
	add	di, CHAN_SIZE
	inc	dx
	cmp	dx, 16
	jb	.chan
	pop	bx
	mov	ax, [es:bx+48]
	mov	[es:6], ax			; the active setup
	mov	dx, cfg_path
	mov	cx, [size]
	call	write_file
	jc	fail
	mov	dx, msg_done
	jmp	done

uninstall:
	mov	dx, bak_path
	mov	ax, 4300h
	int	21h
	jc	nothing				; never changed
	mov	bx, 1000h
	mov	ah, 4Ah
	push	cs
	pop	es
	int	21h
	mov	bx, 1000h
	mov	ah, 48h
	int	21h
	jc	fail
	mov	[bufseg], ax
	mov	dx, bak_path
	mov	si, cfg_path
	call	copy_file
	jc	fail
	mov	dx, bak_path
	mov	ah, 41h
	int	21h
	mov	dx, msg_restored
	jmp	done

notfound:
	mov	dx, msg_nosetup
	jmp	done
nothing:
	mov	ax, 4C00h
	int	21h
done:	mov	ah, 9
	int	21h
	mov	ax, 4C00h
	int	21h
fail:	mov	dx, msg_fail
	mov	ah, 9
	int	21h
	mov	ax, 4C01h
	int	21h
usage:	mov	dx, msg_usage
	mov	ah, 9
	int	21h
	mov	ax, 4C02h
	int	21h

; DS:DX = file -> bufseg:0, CX = size (CF on error or too big)
read_file:
	mov	ax, 3D00h
	int	21h
	jc	.ret
	mov	bx, ax
	push	ds
	mov	ds, [cs:bufseg]
	xor	dx, dx
	mov	cx, MAXSIZE
	mov	ah, 3Fh
	int	21h
	pop	ds
	pushf
	push	ax
	mov	ah, 3Eh
	int	21h
	pop	cx
	popf
	jc	.ret
	cmp	cx, MAXSIZE			; too big for this tool
	cmc
.ret:	ret

; DS:DX = file <- bufseg:0, CX bytes
write_file:
	push	cx
	xor	cx, cx
	mov	ah, 3Ch
	int	21h
	pop	cx
	jc	.ret
	mov	bx, ax
	push	ds
	mov	ds, [cs:bufseg]
	xor	dx, dx
	mov	ah, 40h
	int	21h
	pop	ds
	pushf
	push	ax
	mov	ah, 3Eh
	int	21h
	pop	ax
	popf
	jc	.ret
	cmp	ax, cx
	je	.ret
	stc
.ret:	ret

; copy DS:DX to DS:SI through the buffer (the buffer is used)
copy_file:
	push	si
	call	read_file
	pop	dx
	jc	.ret
	call	write_file
.ret:	ret

skip:	lodsb
	cmp	al, ' '
	je	skip
	cmp	al, 9
	je	skip
	dec	si
	ret

; DS:SI -> ES:DI including the 0 (DI on the 0 afterwards)
strcpy:	lodsb
	stosb
	test	al, al
	jnz	strcpy
	dec	di
	ret

; DS:SI with ES:DI, case insensitive: ZF when equal
strcmpi_es:
.l:	lodsb
	mov	ah, [es:di]
	inc	di
	call	upper
	xchg	al, ah
	call	upper
	cmp	al, ah
	jne	.ret
	test	al, al
	jnz	.l
.ret:	ret

upper:	cmp	al, 'a'
	jb	.ret
	cmp	al, 'z'
	ja	.ret
	sub	al, 20h
.ret:	ret

s_system	db	'\SYSTEM\MIDIMAP.', 0
s_cfg		db	'CFG', 0
s_vsb		db	'VSB', 0
s_adlib		db	'Ad Lib general', 0
s_port		db	'VSBHDA OPL3 FM', 0
msg_done	db	'MIDI Mapper: General MIDI on VSBHDA OPL3 FM', 13, 10, '$'
msg_restored	db	'MIDI Mapper: setup restored', 13, 10, '$'
msg_nosetup	db	'MIDIMAP.CFG has no setup "Ad Lib general"; set up the MIDI Mapper in Control Panel', 13, 10, '$'
msg_fail	db	'VSBMAP: MIDIMAP.CFG could not be changed', 13, 10, '$'
msg_usage	db	'VSBMAP windir [/U]', 13, 10, '$'

bufseg		dw	0
size		dw	0
ext_ofs		dw	0
cfg_path	times 128 db 0
bak_path	times 128 db 0
