;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "SPRITE_DATA"

; mask + image requires 48 bytes (3x8 sprite)
sp_pmissile_img		rmb 48*4*9

; temp variable for testing
sp_pm_frame		rmb 2


	section "CODE"

sp_test_3x8
	ldu sp_pm_frame
	leau 48*4,u
	cmpu #sp_pmissile_img+48*4*9
	blo 1f
	ldu #sp_pmissile_img
1	stu sp_pm_frame

	ldx td_fbuf
	leax 13,x
	lda #7
	sta td_count
	bsr sp_draw_3w

	ldu sp_pm_frame
	leax 2,x
	lda #8
	sta td_count
	bsr sp_draw_3w_flipy

	rts


sp_unpack_3x8
	ldu #sp_pmissile
	ldy #sp_pmissile_img
	sty sp_pm_frame
	lda #9
	sta temp0
1	jsr sp_copy_2x8_to_3x8
	dec temp0
	bne 1b
	rts


;**********************************************************
; draw 3 byte wide sprite
; u points to image data
; x points to destination
; td_count contains height
sp_draw_3w
	lsr td_count
	bcc 1f
	pulu d		; get two bytes of mask
	anda ,x		; AND with screen
	andb 1,x	;
	addd 22,u	; OR with two bytes of image data
	std ,x		; store onto screen
	pulu a		; get next byte of mask
	anda 2,x	; etc.
	ora 23,u
	sta 2,x
	leax 32,x
	;
1	lda td_count
	beq 9f
2	pulu d
	anda ,x
	andb 1,x
	addd 22,u
 	std ,x
	pulu a
	anda 2,x
	ora 23,u
	sta 2,x
	pulu d
	anda 32,x
	andb 33,x
	addd 22,u
	std 32,x
	pulu a
	anda 34,x
	ora 23,u
	sta 34,x
	leax 64,x
	dec td_count
	bne 2b
9	rts

;**********************************************************
; draw 3 byte wide sprite upside down
; u points to image data
; x points to destination
; td_count contains height
sp_draw_3w_flipy
	lsr td_count
	bcc 1f
	pulu d		; get two bytes of mask
	anda ,x		; AND with screen
	andb 1,x	;
	addd 22,u	; OR with two bytes of image data
	std ,x		; store onto screen
	pulu a		; get next byte of mask
	anda 2,x	; etc.
	ora 23,u
	sta 2,x
	leax -32,x
	;
1	lda td_count
	beq 9f
2	pulu d
	anda ,x
	andb 1,x
	addd 22,u
 	std ,x
	pulu a
	anda 2,x
	ora 23,u
	sta 2,x
	pulu d
	anda -32,x
	andb -31,x
	addd 22,u
	std -32,x
	pulu a
	anda -30,x
	ora 23,u
	sta -30,x
	leax -64,x
	dec td_count
	bne 2b
9	rts

;**********************************************************
; copy unshifted 2 byte wide sprite to 3 byte wide shifted frames
; u points to unshifted source data
; y points to destination
sp_copy_2x8_to_3x8
	lda #8
	sta td_count
1	ldd 16,u		; image data
	std 24,y		;
	clr 26,y		; set every 3rd image byte to $00
	pulu d			; mask data
	std ,y++		;
	lda #$ff		; set every 3rd mask byte to $ff
	sta ,y+			;
	dec td_count
	bne 1b

	leau 16,u		; point to next frame

	lda #3
	sta td_count2
2	bsr sp_copy_shift_3x8
	leay 24,y
	dec td_count2
	bne 2b

	leay 24,y		; point to next frame

	rts

; copies and shifts 3x8 sprite
sp_copy_shift_3x8
	lda #8
	sta td_count

1	coma		; set carry
	ldd -24,y	; mask data
	rora
	rorb
	asra
	rorb
	std 24,y
	ldd -23,y
	lsra
	rorb
	lsra
	rorb
	stb 26,y

	ldd ,y		; image data
	lsra
	rorb
	lsra
	rorb
	std 48,y
	ldd 1,y
	lsra
	rorb
	lsra
	rorb
	stb 50,y

	leay 3,y

	dec td_count
	bne 1b

	rts
