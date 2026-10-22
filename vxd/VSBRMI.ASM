;--- VSBRMI.ASM: real mode initialization of VSBVXD (the LE entry point,
;--- called by WIN386 before it switches to protected mode).
;--- A resident DOS VSBHDA would compete with VSBVXD for the sound hardware
;--- (and Windows doesn't start with it): it's unloaded here the way
;--- UNINST.EXE does it - through its own port trapping, so it works with
;--- 386MAX, QEMM and Jemm+QPIEMU (not with VSBHDA /RM0).
;--- VSBHDA ends with int 21h, ah=4Ch as a child of the current PSP and
;--- continues at that PSP:0000 (UNINST.EXE ends with the INT 20h there).
;--- Here the current PSP is WIN386's, so a PSP of our own is made current
;--- first, with a jump back to us at offset 0.
;--- In: SI = environment segment (BLASTER A: the SB port, default 220h).
;--- Out: AX = 0 (Device_Load_Ok), BX = 0 (no excluded pages),
;--- SI = 0 (no instance data), EDX = reference data (0).

	.386
_RCODE segment word use16 public 'RCODE'
	assume cs:_RCODE, ds:_RCODE

rmi_start:
	push cs
	pop ds
	call getbase			; DX = SB base
	mov oldbase, dx
	mov bx, dx
	add dx, 6
	mov al, 1
	out dx, al			; start DSP reset
	mov al, 0
	out dx, al			; reset - to see if VSBHDA answers
	lea dx, [bx+0Eh]
	in al, dx
	test al, 80h			; VSBHDA answers instantly
	jz done
	lea dx, [bx+0Ah]
	in al, dx
	cmp al, 0AAh
	jnz done
	mov ah, 51h
	int 21h
	mov oldpsp, bx
	mov ax, cs			; our PSP: paragraph aligned in psparea
	mov dx, offset psparea + 15
	shr dx, 4
	add dx, ax
	mov ah, 26h			; copy of the current PSP
	int 21h
	push es
	mov es, dx
	mov byte ptr es:[0], 0EAh	; jmp far uninstalled
	mov word ptr es:[1], offset uninstalled
	mov es:[3], cs
	pop es
	mov bx, dx
	mov ah, 50h
	int 21h
	push es
	push si
	push di
	push bp
	mov oldss, ss
	mov oldsp, sp
	mov dx, oldbase
	add dx, 6
	mov al, 1
	out dx, al			; start DSP reset
	mov al, 55h			; uninstall VSBHDA - doesn't return
	out dx, al
uninstalled:				; VSBHDA has ended, DOS jumped to our PSP:0
	cli
	mov ss, cs:oldss
	mov sp, cs:oldsp
	sti
	push cs
	pop ds
	pop bp
	pop di
	pop si
	pop es
	mov bx, oldpsp
	mov ah, 50h
	int 21h
	mov dx, offset msg_unloaded
	mov ah, 9
	int 21h
done:
	xor ax, ax
	xor bx, bx
	xor si, si
	xor edx, edx
	ret

;--- DX = the A value of BLASTER in the environment at SI:0, else 220h
getbase:
	mov dx, 220h
	push es
	mov es, si
	xor di, di
nextvar:
	cmp byte ptr es:[di], 0
	jz gb_done
	mov si, offset blaster
	mov cx, 8			; "BLASTER="
	push di
	repz cmpsb
	pop bx
	jz found
	mov di, bx
	mov cx, -1
	mov al, 0
	repnz scasb			; next variable
	jmp nextvar
found:					; ES:DI = value
	mov al, es:[di]
	inc di
	cmp al, 0
	jz gb_done
	and al, 0DFh
	cmp al, 'A'
	jnz found
	xor dx, dx
nexthex:
	mov al, es:[di]
	inc di
	cmp al, '0'
	jb gb_done
	cmp al, '9'
	jbe decdigit
	and al, 0DFh
	cmp al, 'A'
	jb gb_done
	cmp al, 'F'
	ja gb_done
	sub al, 'A' - 10
	jmp digit
decdigit:
	sub al, '0'
digit:
	shl dx, 4
	or dl, al
	jmp nexthex
gb_done:
	pop es
	ret

blaster		db 'BLASTER='
oldbase		dw 0
oldpsp		dw 0
oldss		dw 0
oldsp		dw 0
msg_unloaded	db 'VSBVXD: VSBHDA unloaded (VSBVXD plays the sound in Windows)', 13, 10, '$'

psparea		db 256 + 16 dup (0)

_RCODE ends

	end rmi_start
