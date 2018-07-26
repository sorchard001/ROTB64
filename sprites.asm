;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

	section "DPVARS"

sp_free_list	rmb 2	; ptr to list of unused sprites
sp_pcol_list	rmb 2	; ptr to list of collidable sprites
sp_ncol_list	rmb 2	; ptr to list of non-collidable sprites
sp_prev_ptr	rmb 2	; points to previous sprite in current list
sp_count	rmb 1	; number of active sprites
sp_col_check	rmb 2	; pointer to collision check code (or bypass)

kill_count	rmb 1	; temporary for demo sound fx

;**********************************************************

	section "DATA"

sp_data		rmb SP_SIZE * CFG_NUM_SPRITES
sp_data_end	equ *

sp_spare	rmb SP_SIZE * 2


;**********************************************************

	section "SPRITE_DATA"

	org CFG_SPRITE_DATA

; mask + image requires 96 bytes (4x12 sprite)

sp_std_img		rmb 96*4
sp_explosion_img	rmb 96*4*4
sp_form_img
sp_boss_img		rmb 96*4*4

;**********************************************************

	section "CODE"

sp_init_all
	ldx #sp_data
	stx sp_free_list
	clra
	sta sp_count
	clrb
	std sp_pcol_list
	std sp_ncol_list
	ldu #sp_std_explosion	; default descriptor
1	stu SP_DESC,x
	sta SP_MISFLG,x
	leax SP_SIZE,x
	stx SP_LINK-SP_SIZE,x
	cmpx #sp_data_end
	bne 1b
	std SP_LINK-SP_SIZE,x
	clr kill_count

	jsr sp_unpack
	rts


; update all collidable sprites (e.g. enemies)
sp_update_collidable
	ldd #sp_update_sp4x12_check_col	; enable player bullet collision detect
	std sp_col_check		;
	ldy #sp_pcol_list-SP_LINK	; initial 'previous' sprite
	jmp sp_update_sp4x12_next

; update all non-collidable sprites (e.g. explosions)
sp_update_non_collidable
	ldd #sp_update_sp4x12_next	; disable player bullet collision detect
	std sp_col_check		;
	ldy #sp_ncol_list-SP_LINK	; initial 'previous' sprite
	jmp sp_update_sp4x12_next

; nb. initial 'previous' sprite comes into play if the first sprite is
; removed from list. The address of the next sprite gets stored in SP_LINK
; of previous sprite which in this case would be the list head pointer.


SCRN_HGT equ TD_TILEROWS*8


pb_col_hit_mac macro
pb_hit_\1
  if \1 < CFG_NUM_PB
	clr pb_data0+\1*PB_SIZE		; disable bullet
	ldu #pb_col_data+\1*PB_COL_SIZE	; point to bullet collision data
  endif
  if \1 < (CFG_NUM_PB - 1)
	bra pb_hit
  endif
  endm

	pb_col_hit_mac 0
	pb_col_hit_mac 1
	pb_col_hit_mac 2
	pb_col_hit_mac 3
	pb_col_hit_mac 4
	pb_col_hit_mac 5
	pb_col_hit_mac 6
	pb_col_hit_mac 7


pb_hit
	incb			; set collision flag
	clr PB_COL_SAVE,u	; disable collision detect
	ldx #pb_zero		; for this bullet
	stx PB_COL_ADDR,u	;
	jmp PB_COL_NEXT,u	; jump to next collision detect


;All player bullets are checked against each sprite
;This needs to be as fast as possible
pb_col_check_mac macro
  if \1 < CFG_NUM_PB
	lda >pb_zero
	anda #0
	cmpa #0
	bne pb_hit_\1
  endif
  endm

pb_col_data equ _pb_col_data + 1
PB_COL_ADDR equ 1-1
PB_COL_MASK equ 4-1
PB_COL_SAVE equ 6-1
PB_COL_NEXT equ 9-1
PB_COL_SIZE equ 9

sp_update_sp4x12_check_col
	ldb SP_COLFLG,y		; check if collision already flagged
	bne 1f
	;clrb				; clear collision flag
_pb_col_data
	pb_col_check_mac 0
	pb_col_check_mac 1
	pb_col_check_mac 2
	pb_col_check_mac 3
	pb_col_check_mac 4
	pb_col_check_mac 5
	pb_col_check_mac 6
	pb_col_check_mac 7
	tstb
	beq sp_update_sp4x12_next	; no hit

1	ldu SP_DESC,y			; point to additional sprite info
	lda SP_SCORE,u
	beq sp_update_sp4x12_next	; no score means don't destroy sprite

_sp_update_sp4x12_destroy
	adda score0
	daa
	sta score0
	lda score1
	adca #0
	daa
	sta score1
	lda score2
	adca #0
	daa
	sta score2

	clr SP_MISFLG,y		; stop missiles tracking this sprite
	ldx SP_EXPL,u		; explosion sound effect
1	jsr snd_start_fx	;

	; turn sprite into explosion
	ldd #sp_std_expl_update_init
	std SP_UPDATEP,y

	jmp [SP_DPTR,u]		; additional code to run on destruction
sp_dptr_rtn			; return from destruction routine

	ldx sp_prev_ptr		; remove sprite from current list
	ldd SP_LINK,y		;
	std SP_LINK,x		;
	ldd sp_ncol_list	; add sprite to non-collidable list
	std SP_LINK,y		;
	sty sp_ncol_list	;

	ldy SP_LINK,x		; next sprite
	beq 1f
	jmp [SP_UPDATEP,y]
1	rts


SND_FX_TAB	fdb SND_TONE2,SND_TONE3,SND_TONE4,SND_TONE5


sp_update_sp4x12_next
	sty sp_prev_ptr
	ldy SP_LINK,y
	beq 1b			; end of list - rts
	jmp [SP_UPDATEP,y]

sp_update_sp4x12
	lda #12			; default sprite height
	sta td_count

	ldd SP_XORD,y	; update xord
	addd SP_XVEL,y
	addd scroll_x
	std SP_XORD,y

	ldx #sp_draw_clip_table	; horizontal clip via lookup
	lsla
	ldx a,x
	stx sp_clip_addr+1	; save it for later as we will run out of regs

	ldx SP_FRAMEP,y
	andb #192	; select sprite frame to suit degree of shift required
	abx		; multiply shift value (0-3) by size of sprite data (96)
	lsrb		; done here by multiplying in place by 1.5
	leau b,x	;

	ldd SP_YORD,y	; update y ord
	addd SP_YVEL,y
	addd scroll_y
	std SP_YORD,y

	bpl 1f			; no clip at top

	cmpd #-11*32
	blt sp_offscreen	; off top of screen

	lslb
	rola
	suba #-3	; same as subtracting -12*32 from D before shift
	lslb
	rola
	lslb
	rola
	sta td_count	; clipped height
	suba #12
	nega
	lsla
	lsla
	leau a,u		; offset start of image data
	ldx td_fbuf		; sprite starts at top of screen
	bra 9f			; skip to horiz part of address calc

1	cmpd #(SCRN_HGT-12)*32
	ble 2f		; no clip at bottom. go to address calc

	subd #SCRN_HGT*32
	bge sp_offscreen	; off bottom of screen

	lslb
	rola
	lslb
	rola
	lslb
	rola
	nega
	sta td_count	; clipped height
	ldd SP_YORD,y
2
	;ldd SP_YORD,y	; y offset
	andb #$e0		; remove sub-pixel bits
	adda td_fbuf	; screen base
	tfr d,x
9	lda SP_XORD,y	; x offset
	leax a,x

sp_clip_addr
	jmp >0		; jump to horizontal clip routine

sp_remove
	clr SP_MISFLG,y		; stop missiles tracking this sprite
	dec sp_count		; reduce sprite count
	ldu sp_prev_ptr		; remove sprite from current list
	ldd SP_LINK,y		;
	std SP_LINK,u		;
	ldd sp_free_list	; add sprite to free list
	std SP_LINK,y		;
	sty sp_free_list	;
	ldy SP_LINK,u		; next sprite
	beq 1f
	jmp [SP_UPDATEP,y]
	;lbne sp_update_sp4x12
1	rts

sp_offscreen
	ldu SP_DESC,y		; pointer to descriptor
	jmp [SP_OFFSCR,u]	; off-screen handler

sp_form_offscreen
	lda SP_XORD,y
	cmpa #-6
	blt sp_remove
	cmpa #34
	bge sp_remove
	ldd SP_YORD,y
	cmpd #-11*32-24*32
	blt sp_remove
	cmpd #(SCRN_HGT*32+24*32)
	bge sp_remove
	jmp sp_update_sp4x12_next



	; horizontal clip table. Thanks to Bosco for this idea!

	fdb sp_offscreen
	fdb sp_offscreen
	fdb sp_offscreen
	fdb sp_offscreen
	fdb sp_draw_sp4x12_clip_h1_l
	fdb sp_draw_sp4x12_clip_h2_l
	fdb sp_draw_sp4x12_clip_h3_l
sp_draw_clip_table
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12
	fdb sp_draw_sp4x12_clip_h3_r
	fdb sp_draw_sp4x12_clip_h2_r
	fdb sp_draw_sp4x12_clip_h1_r
	fdb sp_offscreen
	fdb sp_offscreen
	fdb sp_offscreen
	fdb sp_offscreen
	fdb sp_offscreen


; draw sprite
sp_draw_sp4x12
	lsr td_count
	bcc 1f
	pulu d		; get two bytes of mask
	anda ,x		; AND with screen
	andb 1,x	;
	addd 46,u	; OR with two bytes of image data
	std ,x		; store onto screen
	pulu d		; get next two bytes of mask
	anda 2,x	; etc.
	andb 3,x
	addd 46,u
	std 2,x
	leax 32,x
	;
1	lda td_count
	beq 9f
2	pulu d
	anda ,x
	andb 1,x
	addd 46,u
	std ,x
	pulu d
	anda 2,x
	andb 3,x
	addd 46,u
	std 2,x
	pulu d
	anda 32,x
	andb 33,x
	addd 46,u
	std 32,x
	pulu d
	anda 34,x
	andb 35,x
	addd 46,u
	std 34,x
	leax 64,x
	dec td_count
	bne 2b
9	jmp [sp_col_check]


; draw clipped sprite 3 bytes wide
; clip at left
sp_draw_sp4x12_clip_h3_l
	leau 1,u	; advance image pointer
	leax 1,x	; advance screen pointer
; clip at right
sp_draw_sp4x12_clip_h3_r
1	pulu d
	anda ,x
	andb 1,x
	addd 46,u
	std ,x
	pulu d		; grab both bytes to advance pointer correctly...
	anda 2,x	; ... but don't use second byte
	ora 46,u
	sta 2,x
	leax 32,x
	dec td_count
	bne 1b
	jmp [sp_col_check]


; draw clipped sprite 2 bytes wide
; clip at left
sp_draw_sp4x12_clip_h2_l
	leau 2,u
	leax 2,x
; clip at right
sp_draw_sp4x12_clip_h2_r
1	ldd ,u
	anda ,x
	andb 1,x
	addd 48,u
	std ,x
	leau 4,u
	leax 32,x
	dec td_count
	bne 1b
	jmp [sp_col_check]


; draw clipped sprite 1 byte wide
; clip at left
sp_draw_sp4x12_clip_h1_l
	leau 3,u
	leax 3,x
; clip at right
sp_draw_sp4x12_clip_h1_r
1	lda ,u
	anda ,x
	ora 48,u
	sta ,x
	leau 4,u
	leax 32,x
	dec td_count
	bne 1b
	jmp [sp_col_check]

;**********************************************************

sp_unpack

	ldu #sp_std_ps_params
	bsr sp_copy_3x12_to_4x12

	ldu #sp_explosion_ps_params
	bsr sp_copy_3x12_to_4x12

	rts


; preshift params
; frames,dest,source

sp_std_ps_params
	fcb 1
	fdb sp_std_img,sp_std2
	;fdb sp_std_img,sp_std
	;fdb sp_std_img,sp_tank

sp_explosion_ps_params
	fcb 4
	fdb sp_explosion_img,sp_explosion



	section "DPVARS"

sp4x12_ps_params	equ *
sp4x12_ps_src		rmb 2
sp4x12_ps_dst		rmb 2
sp4x12_ps_frames	rmb 1
sp4x12_ps_count		rmb 1


	section "CODE"

sp_copy_3x12_to_4x12
	bsr sp4x12_ps_first_imm
1	bsr sp4x12_ps_next
	bne 1b
	rts


sp4x12_ps_first
	ldu sp4x12_ps_params
sp4x12_ps_first_imm
	pulu a,x
	ldu ,u
	sta sp4x12_ps_frames
	bra 5f

sp4x12_ps_next
	ldx sp4x12_ps_dst
	lda sp4x12_ps_count	; number of shifted frames remaining
	bne 1f			; do next shifted frame

	leax 48,x
	ldu sp4x12_ps_src	;
	leau 36,u		; setup next source frame
5	bsr sp4x12_ps_copy0	; copy 3x12 source to 4x12 dest
	stu sp4x12_ps_src
	stx sp4x12_ps_dst
	lda #6			; setup 6 half images for copy/shift
	sta sp4x12_ps_count
	rts

1	bsr sp4x12_ps_shift
	lda sp4x12_ps_count
	lsra
	bcc 2f
	leax 48,x
2	stx sp4x12_ps_dst
	dec sp4x12_ps_count
	bne 9f
	dec sp4x12_ps_frames
9	rts


; copies 3x12 mask & image to 4 byte wide format
; u source, x destination
sp4x12_ps_copy0
	lda #12
	sta td_count
1	ldd 36,u		; image data
	std 48,x		;
	lda 38,u		;
	clrb			; set every 4th image byte to $00
	std 50,x		;
	pulu d			; mask data
	std ,x++		;
	pulu a			;
	ldb #$ff		; set every 4th mask byte to $ff
	std ,x++		;
	dec td_count
	bne 1b
	rts

; copies and shifts 4x12 mask & image by one pixel
; mask & image are copy/shifted from -48,x to 48,x
; only 6 lines processed to keep cycles below 1000
sp4x12_ps_shift
	lda #6
	sta td_count

1	coma		; set carry
	ldd -48,x	; mask data
	rora
	rorb
	asra
	rorb
	std 48,x
	ldd -47,x
	lsra
	rorb
	lsra
	rorb
	stb 50,x
	ldd -46,x
	lsra
	rorb
	lsra
	rorb
	stb 51,x

	ldd ,x		; image data
	lsra
	rorb
	lsra
	rorb
	std 96,x
	ldd 1,x
	lsra
	rorb
	lsra
	rorb
	stb 98,x
	ldd 2,x
	lsra
	rorb
	lsra
	rorb
	stb 99,x

	leax 4,x

	dec td_count
	bne 1b

	rts

