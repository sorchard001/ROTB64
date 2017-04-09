;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************
;
; Misc graphics support routines
;

	section "CODE"


;**********************************************************
; Swap front and back frame buffers

; wait for vsync then flip
flip_frame_buffers
  	lda $ff02	; clear fs flag
1	lda $ff03	; check for fs
	bpl 1b		;
	bra 3f		; flip

; wait for vsync while generating sound, then flip
flip_frame_buffers_snd
  	lda $ff02	; clear fs flag

2	ldx #50
1	lda $ff03	; check for fs
	bmi 3f		;
	leax -1,x
	bne 1b		; 16 cycles per loop
	lda [snd_buf_ptr]
	sta $ff20
	inc snd_buf_ptr+1
	bra 2b

3	com frmflag
	beq 90f
	lda #(FBUF0+CFG_TOPOFF) >> 8
	sta td_fbuf
	CFG_MAC_SET_FBUF1
	rts
90	lda #(FBUF1+CFG_TOPOFF) >> 8
	sta td_fbuf
	CFG_MAC_SET_FBUF0
	rts

;**********************************************************
; Pixel fade effect using ordered dither

pf_tog		equ temp0
pf_fcount	equ temp1
pf_vcount	equ temp2

pixel_fade
	jsr snd_clear_buf
	
	; copy front buffer to back
	; so display doesn't jump up and down
	ldd td_fbuf
	tfr d,x				; back buffer address in x
	eora #FBUF_TOG_HI
	tfr d,u				; front buffer address in u
	ldy #TD_SBSIZE >> 1
1	ldd ,u++
	std ,x++
	leay -1,y
	bne 1b

	lda #32				; 16 levels of dither over 32 frames
	sta pf_fcount
	ldu #pf_dither_table
	clr pf_tog
3	
	ldx td_fbuf			; top of screen
	ldb 1,u				; get next row offset
	abx					; move to required row
	lda #TD_TILEROWS*2	; number of rows
	sta pf_vcount		;

2	ldy #16				; 16 words per row
1	ldd ,x				; apply dither mask
	anda ,u				;
	andb ,u				;
	std ,x++			;
	leay -1,y			;
	bne 1b				; loop until row done
	leax 96,x
	dec pf_vcount
	bne 2b				; next row

	jsr flip_frame_buffers

	com pf_tog			; advance dither pattern every 2 frames
	bne 5f				; to keep odd & even frames the same
	leau 2,u			;
5	dec pf_fcount		;
	bne 3b				; next frame

	rts

; 1st byte is mask, 2nd byte is row offset
pf_dither_table
	fcb $3f, 0,$f3,64,$f3, 0,$3f,64
	fcb $cf,32,$fc,96,$fc,32,$cf,96
	fcb $cf, 0,$fc,64,$fc, 0,$cf,64
	fcb $3f,32,$f3,96,$f3,32,$3f,96

; ordered dither matrix
; 1  9  3 11
;13  5 15  7
; 4 12  2 10
;16  8 14  6

;**********************************************************
; draw character
; ascii code in B
; destination in U
; leaves U pointing to next position

	section "DPVARS"

char_fg		rmb 1		; character foreground colour mask
char_bg		rmb 1		; character background colour mask

	section "CODE"

draw_char
	lda #5
	mul
	addd #allchars-(32*5)
	tfr d,x
;intr_char_x
	ldb #-128
1	lda char_fg		; apply fg/bg colours
	eora char_bg	;
	anda ,x+		;
	eora char_bg	;
	sta b,u
	addb #32
	cmpb #32
	bne 1b
	leau 1,u
	rts
