;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "_STRUCT"
	org 0

SPM_FLAG		rmb 1	; sprite valid if non-zero
SPM_XORD		rmb 2	; x * 64
SPM_YORD		rmb 2	; y * 32
SPM_XVEL		rmb 2	; x velocity * 64
SPM_YVEL		rmb 2	; y velocity * 32
SPM_DIR			rmb 1	; direction

SPM_SIZE		equ *	; size of data structure


	section "SPRITE_DATA"

; mask + image requires 48 bytes (3x8 sprite)
sp_pmissile_img		rmb 48*4*9

sp_data_pm1		rmb SPM_SIZE
sp_data_pm2		rmb SPM_SIZE


	section "CODE"

pmiss_vel_table
	mac_velocity_table 3


sp_init_3x8
	jsr sp_unpack_3x8
	clr sp_data_pm1
	clr sp_data_pm2
	rts

sp_test_3x8_launch
	ldy #sp_data_pm1
	lda SPM_FLAG,y
	beq 1f
	ldy #sp_data_pm2
	lda SPM_FLAG,y
	bne 9f

1	inca
	sta SPM_FLAG,y

	ldd #(PLYR_CTR_X-4)*64
	std SPM_XORD,y
	ldd #(PLYR_CTR_Y-3)*32
	std SPM_YORD,y

	ldx #pmiss_vel_table
	ldb player_dir
	andb #30
	stb SPM_DIR,y
	lslb
	abx
	ldd ,x
	std SPM_XVEL,y
	ldd 2,x
	std SPM_YVEL,y

9	rts


sp_test_3x8_update
	ldy #sp_data_pm1
	bsr sp_test_3x8_update_one
	ldy #sp_data_pm2

sp_test_3x8_update_one
	lda SPM_FLAG,y
	beq 9b
	ldx #pmiss_vel_table
	ldb [rnd_ptr]
	eorb SPM_XORD,y
	andb #4
	subb #2
	;ldb #0
	addb SPM_DIR,y
	stb SPM_DIR,y
	andb #30
	lslb
	abx
	ldd ,x
	std SPM_XVEL,y
	ldd 2,x
	std SPM_YVEL,y

	ldx #sp_update_3x8
	lda SPM_DIR,y
	anda #30
	cmpa #16
	bls 1f
	ldx #sp_update_3x8_flip
	nega
	adda #32
1	ldb #96
	mul
	addd #sp_pmissile_img
	tfr d,u

	jmp ,x


;**********************************************************

sp_update_3x8

	lda #8
	sta td_count	; default height

	ldd SPM_XORD,y	; update xord
	addd SPM_XVEL,y
	addd scroll_x
	std SPM_XORD,y

	ldx #sp_draw_3x8_clip_table	; horizontal clip via lookup
	lsla
	ldx a,x
	stx 50f+1	; save it for later as we will run out of regs

	andb #192	; select sprite frame to suit degree of shift required
	lsrb		; multiply shift value (0-3) by size of sprite data (48)
	leau b,u	; done here by multiplying in place by 3/4
	lsrb
	leau b,u

	ldd SPM_YORD,y	; update y ord
	addd SPM_YVEL,y
	addd scroll_y
	std SPM_YORD,y
	bpl 1f			; no clip at top

	cmpd #-7*32
	blt sp_3x8_remove	; off top of screen

	inca			; add 8*32 to D
	lslb
	rola
	lslb
	rola
	lslb
	rola
	sta td_count	; clipped height
	nega
	adda #8
	leau a,u		; offset start of image data (x3)
	lsla			;
	leau a,u		;
	ldx td_fbuf		; sprite starts at top of screen
	bra 9f			; skip to horiz part of address calc

1	cmpd #(SCRN_HGT-8)*32
	ble 2f		; no clip at bottom. go to address calc

	subd #SCRN_HGT*32
	bge sp_3x8_remove	; off bottom of screen

	lslb
	rola
	lslb
	rola
	lslb
	rola
	nega
	sta td_count	; clipped height
	ldd SPM_YORD,y

2	andb #$e0		; remove sub-pixel bits
	adda td_fbuf	; screen base
	tfr d,x
9	lda SPM_XORD,y	; x offset
	leax a,x

50	jmp >0		; jump to horizontal clip routine


sp_3x8_remove
	clr SPM_FLAG,y
	rts

;**********************************************************

sp_update_3x8_flip

	lda #8
	sta td_count	; default height

	ldd SPM_XORD,y	; update xord
	addd SPM_XVEL,y
	addd scroll_x
	std SPM_XORD,y

	ldx #sp_draw_3x8_clip_table_flip	; horizontal clip via lookup
	lsla
	ldx a,x
	stx 50f+1	; save it for later as we will run out of regs

	andb #192	; select sprite frame to suit degree of shift required
	lsrb		; multiply shift value (0-3) by size of sprite data (48)
	leau b,u	; done here by multiplying in place by 3/4
	lsrb
	leau b,u

	ldd SPM_YORD,y	; update y ord
	addd SPM_YVEL,y
	addd scroll_y
	std SPM_YORD,y
	bpl 1f			; no clip at top

	cmpd #-7*32
	blt sp_3x8_remove	; off top of screen

	inca			; add 8x32 to D
	lslb
	rola
	lslb
	rola
	lslb
	rola
	sta td_count	; clipped height
	ldd SPM_YORD,y
	bra 2f			; go to address calc

1	cmpd #(SCRN_HGT-8)*32
	ble 2f			; no clip at bottom. go to address calc

	subd #SCRN_HGT*32
	bge sp_3x8_remove	; off bottom of screen

	lslb
	rola
	lslb
	rola
	lslb
	rola
	nega
	sta td_count			; clipped height
	nega
	adda #8
	leau a,u				; offset start of image data (x3)
	lsla					;
	leau a,u				;
	ldd #(SCRN_HGT-1)*32	; draw at bottom of screen
	bra 8f

2	addd #256-32	; adjustment for flipped sprite
	andb #$e0		; remove sub-pixel bits
8	adda td_fbuf	; screen base
	tfr d,x
9	lda SPM_XORD,y	; x offset
	leax a,x

50	jmp >0		; jump to horizontal clip routine

;**********************************************************

	fdb sp_3x8_remove
	fdb sp_draw_3w_clip_h1_l
	fdb sp_draw_3w_clip_h2_l
sp_draw_3x8_clip_table
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w
	fdb sp_draw_3w_clip_h2_r
	fdb sp_draw_3w_clip_h1_r
	fdb sp_3x8_remove

	; sp_3x8_remove shared between tables

	fdb sp_draw_3w_clip_h1_l_flip
	fdb sp_draw_3w_clip_h2_l_flip
sp_draw_3x8_clip_table_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_flip
	fdb sp_draw_3w_clip_h2_r_flip
	fdb sp_draw_3w_clip_h1_r_flip
	fdb sp_3x8_remove

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


; draw clipped sprite 2 bytes wide
; clip at left
sp_draw_3w_clip_h2_l
	leau 1,u
	leax 1,x
; clip at right
sp_draw_3w_clip_h2_r
1	ldd ,u
	anda ,x
	andb 1,x
	addd 24,u
	std ,x
	leau 3,u
	leax 32,x
	dec td_count
	bne 1b
	rts

; draw clipped sprite 1 byte wide
; clip at left
sp_draw_3w_clip_h1_l
	leau 2,u
	leax 2,x
; clip at right
sp_draw_3w_clip_h1_r
1	lda ,u
	anda ,x
	ora 24,u
	sta ,x
	leau 3,u
	leax 32,x
	dec td_count
	bne 1b
	rts


;**********************************************************
; draw 3 byte wide sprite upside down
; u points to image data
; x points to destination
; td_count contains height
sp_draw_3w_flip
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

; draw clipped sprite 2 bytes wide
; clip at left
sp_draw_3w_clip_h2_l_flip
	leau 1,u
	leax 1,x
; clip at right
sp_draw_3w_clip_h2_r_flip
1	ldd ,u
	anda ,x
	andb 1,x
	addd 24,u
	std ,x
	leau 3,u
	leax -32,x
	dec td_count
	bne 1b
	rts

; draw clipped sprite 1 byte wide
; clip at left
sp_draw_3w_clip_h1_l_flip
	leau 2,u
	leax 2,x
; clip at right
sp_draw_3w_clip_h1_r_flip
1	lda ,u
	anda ,x
	ora 24,u
	sta ,x
	leau 3,u
	leax -32,x
	dec td_count
	bne 1b
	rts

;**********************************************************

sp_unpack_3x8
	ldu #sp_pmissile
	ldy #sp_pmissile_img
	lda #9
	sta temp0
1	jsr sp_copy_2x8_to_3x8
	dec temp0
	bne 1b
	rts

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