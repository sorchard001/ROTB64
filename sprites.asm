;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

	section "DPVARS"

sp_free_list	rmb 2	; ptr to list of unused sprites
sp_pcol_list	rmb 2	; ptr to list of collidable sprites
sp_ncol_list	rmb 2	; ptr to list of non-collidable sprites
sp_aux_list	rmb 2	; ptr to additional layer of sprites
sp_prev_ptr	rmb 2	; points to previous sprite in current list
sp_count	rmb 1	; number of active sprites
sp_col_check	rmb 2	; pointer to collision check code (or bypass)
sp_ref_count	rmb 1

kill_count	rmb 1	; temporary for demo sound fx

;**********************************************************

	section "DATA"

sp_data		rmb SP_SIZE * CFG_NUM_SPRITES
sp_data_end	equ *

sp_spare	rmb SP_SIZE * 2


;**********************************************************

	section "SPRITE_DATA"

	org CFG_SPRITE_DATA

; memory reserved for preshifted sprite images
; preshifted masks & images require 96*4 bytes (4x12 sprite)

sp_fball_grfx_ps
sp_std_grfx_ps		rmb 96*4*2

sp_expl_grfx_ps		rmb 96*4*4

sp_rot_grfx_ps
sp_form_grfx_ps
sp_bonus_grfx_ps
sp_boss_grfx_ps		rmb 96*4*4

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
	std sp_aux_list
	ldu #sp_expl_desc	; default descriptor
1	stu SP_DESC,x
	sta SP_MISFLG,x
	leax SP_SIZE,x
	stx SP_LINK-SP_SIZE,x
	cmpx #sp_data_end
	bne 1b
	std SP_LINK-SP_SIZE,x
	clr kill_count
	clr sp_ref_count

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

; update aux layer of sprites as collidable
sp_update_aux_collidable
	ldd #sp_update_sp4x12_check_col	; enable player bullet collision detect
	std sp_col_check		;
	ldy #sp_aux_list-SP_LINK	; initial 'previous' sprite
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
	clrb				; clear collision flag
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

	ldu SP_DESC,y			; point to additional sprite info
	ldd SP_BHIT,u			; code to run on bullet hit
	beq sp_update_sp4x12_next	; null pointer means bullet proof
	std SP_UPDATEP,y
	bra sp_update_sp4x12_next




sp_update_sp4x12_next
	sty sp_prev_ptr
	ldy SP_LINK,y
	beq 1f			; end of list - rts
	jmp [SP_UPDATEP,y]
1	rts

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
	andb #$e0	; remove sub-pixel bits
	adda td_fbuf	; screen base
	tfr d,x
9	lda SP_XORD,y	; x offset
	leax a,x

sp_clip_addr
	jmp >0		; jump to horizontal clip routine

sp_offscreen
	ldu SP_DESC,y		; pointer to descriptor
	jmp [SP_OFFSCR,u]	; off-screen handler


;**********************************************************
; Helper routines

sp_update_explode_ref
	dec sp_ref_count
sp_update_explode
	ldx #sp_expl_update_0	; set up for explosion
sp_update_explode_custom
	stx SP_UPDATEP,y
	ldu SP_DESC,y		; point to additional sprite info
	lda SP_SCORE,u
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
	jsr snd_start_fx	;

	ldx sp_prev_ptr		; remove sprite from current list
	ldd SP_LINK,y		;
	std SP_LINK,x		;
	ldd sp_ncol_list	; add sprite to non-collidable list
	std SP_LINK,y		;
	sty sp_ncol_list	;

	ldy SP_LINK,x		; next sprite
	beq 1f
	jmp [SP_UPDATEP,y]


sp_remove_ref
	dec sp_ref_count
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
1	rts



;**********************************************************

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
	fdb sp_std_grfx_ps,sp_std2

sp_explosion_ps_params
	fcb 4
	fdb sp_expl_grfx_ps,sp_explosion



	section "DPVARS"

sp4x12_ps_src		rmb 2
sp4x12_ps_dst		rmb 2
sp4x12_ps_frames	rmb 1
sp4x12_ps_count		rmb 1


	section "CODE"

sp_copy_3x12_to_4x12
	bsr sp4x12_ps_setup
1	bsr sp4x12_ps_next
	bne 1b
	rts


sp4x12_ps_setup
	pulu a,x
	sta sp4x12_ps_frames
	leax -48,x
	stx sp4x12_ps_dst
	ldu ,u
	leau -36,u
	stu sp4x12_ps_src
	clr sp4x12_ps_count
	rts


sp4x12_ps_next
	lda sp4x12_ps_frames	; safety check
	beq 9f			; exit if already done
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
	;leax 48,x
	;stx sp4x12_ps_dst
	;leau 36,u		; setup next source frame
	;stu sp4x12_ps_src	;
	dec sp4x12_ps_frames
9	rts


; copies 3x12 mask & image to 4 byte wide format
; u source, x destination
; approx 800 cycles
sp4x12_ps_copy0
	lda #12
	sta td_count
1	ldd 36,u	; 6 ; image data
	std 48,x	; 6 ;
	lda 38,u	; 5 ;
	clrb		; 2 ; set every 4th image byte to $00
	std 50,x	; 6 ;
	pulu d		; 7 ; mask data
	std ,x++	; 8 ;
	pulu a		; 6 ;
	ldb #$ff	; 2 ; set every 4th mask byte to $ff
	std ,x++	; 8 ;
	dec td_count	; 6 ;
	bne 1b		; 3 ; (65)
	rts

; copies and shifts 4x12 mask & image by one pixel
; mask & image are copy/shifted from -48,x to 48,x
; only 6 lines processed to keep cycles below 1000
; approx 800 cycles
sp4x12_ps_shift
	lda #6
	sta td_count

1	coma		; 2 ; set carry
	ldd -48,x	; 6 ; mask data
	rora		; 2 ;
	rorb		; 2 ;
	asra		; 2 ;
	rorb		; 2 ;
	std 48,x	; 6 ;
	ldd -47,x	; 6 ;
	lsra		; 2 ;
	rorb		; 2 ;
	lsra		; 2 ;
	rorb		; 2 ;
	stb 50,x	; 5 ;
	ldd -46,x	; 6 ;
	lsra		; 2 ;
	rorb		; 2 ;
	lsra		; 2 ;
	rorb		; 2 ;
	stb 51,x	; 5 ;

	ldd ,x		; 5 ; image data
	lsra		; 2 ;
	rorb		; 2 ;
	lsra		; 2 ;
	rorb		; 2 ;
	std 96,x	; 6 ;
	ldd 1,x		; 6 ;
	lsra		; 2 ;
	rorb		; 2 ;
	lsra		; 2 ;
	rorb		; 2 ;
	stb 98,x	; 5 ;
	ldd 2,x		; 6 ;
	lsra		; 2 ;
	rorb		; 2 ;
	lsra		; 2 ;
	rorb		; 2 ;
	stb 99,x	; 5 ;
	leax 4,x	; 5 ;
	dec td_count	; 6 ;
	bne 1b		; 3 ;

	rts

