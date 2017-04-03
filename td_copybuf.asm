;**********************************************************
; Tiledriver Background Engine
; Copyright 2015 S. Orchard
;**********************************************************
;
; copy buffer to screen
;
; upper section of screen is copied from bptr
; lower section of screen is copied from start of buffer
;
; uses cc & dp to move data
; - interrupts must be completely disabled
; - care required when accessing dp vars
;
;*******************************************


	section "CODE"


td_copybuf
	pshs cc,dp
	sts 99f+2		; save stack pointer

	ldd snd_buf_ptr		; write sound buffer pointer 
	std copy_snd_ptr	; to local self-mod var
	
	ldd td_bptr		; source address starts from buffer offset
	addd td_sbuf	;
	tfr d,u			;
	
	lds td_fbuf		; destination address is top of screen
	
	ldd #TD_SBSIZE
	subd td_bptr	; number of bytes to copy for upper section
	ldx #1f			; return address
	bra td_copy_routine
1
	ldd >td_bptr	; number of bytes to copy for lower section
	ldu >td_sbuf	; source address is now start of buffer
	ldx #1f			; return address
	bra td_copy_routine

1	ldb >copy_snd_ptr+1	; update sound buffer pointer
	stb >snd_buf_ptr+1	; (only need to update low byte)
99	lds #0				; restore stack pointer
	puls cc,dp,pc

	
; macro to copy 8 bytes from u to s-8
td_copy8_mac	macro
	pulu cc,dp,d,x,y
	pshs cc,dp,d,x,y
	leas 16,s
	endm	


; fast copy routine
; u - source address
; s - destination address
; d - number of bytes to copy
; x - return address
;
; care required: cc & dp regs are not preserved
	
td_copy_routine
	stx 99f+1		; save return address
	sta >td_count

	lsrb
	bcc 1f
	lda ,u+			; copy 1 byte
	sta ,s+

1	lsrb
	bcc 1f
	pulu x			; copy 2 bytes
	stx ,s++

1	lsrb
	bcc 1f
	pulu x,y		; copy 4 bytes
	stx ,s++
	sty ,s++

1	leas 8,s		; adjustment to align with stack ops
	lsrb
	stb >td_count2	; need to save b
	bcc 1f
	td_copy8_mac	; copy 8 bytes
	
1	lsr >td_count2
	bcc 1f
	td_copy8_mac	; copy 16 bytes
	td_copy8_mac

1	lsr >td_count2
	bcc 1f
	td_copy8_mac	; copy 32 bytes
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac

1	lsr >td_count2
	bcc 1f
	td_copy8_mac	; copy 64 bytes
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac

1	lsr >td_count2	; set up td_count with number of 128 byte blocks remaining
	rol >td_count	;
	beq 90f			; nothing to do
copy_snd_ptr equ *+1
2	lda >0				; update dac every 128 bytes
	sta $ff20			;
	inc copy_snd_ptr+1	;
	td_copy8_mac		; copy count * 128 bytes
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	td_copy8_mac
	dec >td_count
	bne 2b

90	leas -8,s		; undo adjustment
99	jmp >0			; return to caller
