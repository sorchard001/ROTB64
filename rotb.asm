;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************


	include "stdmacros.asm"

DBG_RASTER 			equ 1
DBG_NO_PLAYER_COL	equ 1
;DBG_NO_PLAYER_MOVE	equ 1
DBG_SKIP_INTRO		equ 1

; 64K mode
CFG_64K				equ 1

; number of lives (bcd)
CFG_LIVES			equ $03

; joystick thresholds
CFG_JOYSTK_LO		equ $40
CFG_JOYSTK_HI		equ $c0

; pia cr setup. All interrupt sources disabled.
CFG_FF01_JOY_X		equ $34		; also selects DAC sound
CFG_FF01_JOY_Y		equ $3c
CFG_FF23_DIS_SND	equ $34
CFG_FF23_ENA_SND	equ $3c

; start of code (must be page aligned)
CFG_CODE_ADDR	equ $1c00

; start of VDG frame buffer
CFG_FRAME_BUF	equ $400

; stack address
CFG_STACK		equ $400

; number of rows of tiles in play area
CFG_TILEROWS	equ 11

; start of background shift buffers
;CFG_SBUFF		equ $8000-(CFG_TILEROWS*256*4)
CFG_SBUFF		equ $8000

; address of unpacked sprite data
CFG_SPRITE_DATA		equ CFG_SBUFF + (CFG_TILEROWS*256*4)

; address of code that needs be copied to RAM
; (experimental: just copies a small amount of code)
CFG_RAMCODE_PUT		equ __end_code

; destination address of code copied to RAM
CFG_RAMCODE_ORG		equ CFG_RAMCODE_PUT
;CFG_RAMCODE_ORG		equ __end_data

; address to construct waves for cyd
CFG_CYD_WAVES_ADDR	equ CFG_SBUFF


; macro to set video mode
CFG_MAC_SET_VIDMODE macro
	lda #$e0
	sta $ff22
    sta $ffc5
	endm

; macros to set SAM vdg display address
CFG_MAC_SET_FBUF0 macro
	sta $ffc9	; 1K on
	sta $ffcc	; 4K off
	endm
CFG_MAC_SET_FBUF1 macro
	sta $ffc8	; 1K off
	sta $ffcd	; 4K on
	endm



; offset of play area from top of screen (must be multiple of 256)
CFG_TOPOFF		equ $100

; number of sprites
CFG_NUM_SPRITES	equ 8

; number of player bullets (max 8)
CFG_NUM_PB		equ 6

;**********************************************************

; display frame buffers
FBUF_SIZE	equ 3072
FBUF0		equ CFG_FRAME_BUF
FBUF1		equ FBUF0+FBUF_SIZE

FBUF_TOG_HI	equ (FBUF0 ^ FBUF1) >> 8	; bit pattern to toggle between frame addresses

TOGMODE	macro
	lda $ff22
	eora #$18
	sta $ff22
	endm

;**********************************************************

	section "DPVARS"

	org 0

DPVARS

frmflag			rmb 1
workload		rmb 1
player_dir		rmb 1
scroll_x_ctr	rmb 1
scroll_y_ctr	rmb 1
scroll_x_inc	rmb 1
scroll_y_inc	rmb 1
scroll_x		rmb 2	; background scroll x for current frame (add to all coords)
scroll_y		rmb 2	; background scroll y for current frame (add to all coords)
score2			rmb 1
score1			rmb 1
score0			rmb 1
task_ptr		rmb 2
rnd_ptr			rmb 2
mode_routine	rmb 2
death_tmr		rmb 1
bonus_tmr		rmb 1
bonus_ptr		rmb 2
lives			rmb 1

 if DBG_RASTER
show_raster		rmb 1
 endif

temp0			rmb 1
temp1			rmb 1
temp2			rmb 1
temp3			rmb 1
temp4			rmb 1
temp5			rmb 1
temp6			rmb 1
temp7			rmb 1
temp8			rmb 1
temp9			rmb 1
temp10			rmb 1
temp11			rmb 1
temp12			rmb 1

;**********************************************************

	section "DATA"

rndtable		rmb 48
rndtable_end	equ *

;**********************************************************

	section "RAMCODE"

	setdp DPVARS >> 8

	org CFG_RAMCODE_ORG
	put CFG_RAMCODE_PUT

;**********************************************************

	section "CODE"

	org CFG_CODE_ADDR
	setdp DPVARS >> 8

	; rotb_tune must be page aligned
	include "rotb_tune.asm"


code_entry
	;orcc #$50

	lda #DPVARS >> 8
	tfr a,dp
	setdp DPVARS >> 8

	clr $ff48		; disable disk motor & nmi

	lds #CFG_STACK

	ldd #$34fc
	ldx #$ff00
	sta 1,x
	sta 3,x
	ldx #$ff20
	clr 1,x			; set non-DAC bits of $ff20 as inputs
	stb ,x			;
	sta 1,x
	ora #8			; enable sound
	sta 3,x

	; switch to map 1
  if CFG_64K
	sta $ffdf
  endif


  ; relocate code if required
  if (CFG_RAMCODE_PUT != CFG_RAMCODE_ORG)
	ldu #CFG_RAMCODE_PUT
	ldx #CFG_RAMCODE_ORG
1	lda ,u+
	sta ,x+
	cmpx #__end_ramcode_org
	blo 1b
  endif

  if DBG_RASTER
	clr show_raster
  endif

	ldx #rndtable			; prefill random number table
	stx rnd_ptr
	ldb #(rndtable_end - rndtable)
1	jsr rnd_number
	decb
	bne 1b

	jsr controls_init		; initialise key/joy control
	jsr snd_init			; initialise sound engine
	jsr td_init				; initialise tile engine
	jsr colour_change_init	; initialise palette

	clra
	clrb
	ldx #FBUF0				; clear frame buffers
1	std ,x++
	cmpx #FBUF1+FBUF_SIZE
	blo 1b

	clr td_fbuf+1			; initialise double buffering state
	clr frmflag
	jsr flip_frame_buffers


	CFG_MAC_SET_VIDMODE

	jsr intro

	jmp START_GAME



;**********************************************************

	section "CODE"


	include "grfx/tiledata.asm"
	include "grfx/sp_test.asm"
	include "grfx/sp_explosion.asm"
	include "grfx/sp_flap_2.asm"
	include "grfx/sp_boss.asm"
	include "grfx/sp_player.asm"
	include "grfx/sp_pmissile.asm"
	include "grfx/chardata_digits.asm"
	include "grfx/allchars.asm"

	include "vel_table.asm"
	include "screen.asm"
	include "player.asm"
	include "sprite_desc.asm"
	include "sprites.asm"
	include "sprites_3x8.asm"
	include "pmissiles.asm"
	include "enemies.asm"
	include "sound.asm"
	include "colour_change.asm"
	include "controls.asm"
	include "intro.asm"

TD_SBUFF	equ CFG_SBUFF		; start of shift buffers
TD_TILEROWS	equ CFG_TILEROWS	; number of rows of tiles

	include "tiledriver.asm"

START_GAME

RESTART_GAME

	ldd #$aaaa				; prefill shift buffers
	ldx #TD_SBUFF
1	std ,x++
	cmpx #TD_SBEND
	blo 1b

	clra
	clrb
	ldx #FBUF0				; clear score area
1	std FBUF1-FBUF0,x
	std ,x++
	cmpx #FBUF0+CFG_TOPOFF
	blo 1b

	; initialise score display
	clrb
	ldu #FBUF0+CFG_TOPOFF+SCORE_POS+6
	jsr draw_digit
	clrb
	ldu #FBUF1+CFG_TOPOFF+SCORE_POS+6
	jsr draw_digit

	lda #4
	sta en_std_max
	lda #CFG_LIVES
	sta lives
	clra
	clrb
	std score2
	sta score0

START_LEVEL
	clra
	clrb
	sta en_count
	std missile_offset_x
	std missile_offset_y

NEXT_LIFE

START_DIR	equ 8
	lda #START_DIR
	sta player_dir
	ldd player_speed_table+START_DIR
	std scroll_x_ctr
	std scroll_x_inc

	jsr sp_init_all
	jsr pb_init_all
	jsr en_init_all
	jsr pmiss_init

	ldd #fl_mode_normal
	std mode_routine
	ldd #task_table_normal
	std task_ptr
	clr bonus_tmr

	jsr warp_intro

;-------------------------

MLOOP

	; update sounds
	jsr snd_update

	clr workload
	jsr move_player

	; load-levelling delay
1	lda #2
	suba workload
	beq 1f
	lsla
	lsla
	sta td_count
3	ldx #100				;
2	leax -1,x				;
	bne 2b					; 8 cycles per loop
30	lda [snd_buf_ptr]	;
	sta $ff20			;
	inc snd_buf_ptr+1	;
	dec td_count		;
	bne 3b				;
1

	; copy background to frame buffer
	jsr td_copybuf

	jsr scan_keys

	jsr [mode_routine]

	jsr pmiss_update


	; update player velocity (affected by key scan & sometimes mode_routine)
	ldx #player_speed_table
	ldb player_dir
	andb #30
	ldu b,x
	stu scroll_x_inc

	; show position of raster on screen
  if DBG_RASTER
	lda show_raster
	beq 1f
	TOGMODE
	TOGMODE
1
  endif

	jsr flip_frame_buffers_snd


	; 1 - CHANGE COLOUR SET
1	lda #1
	bita keytable+1
	bne 1f
	jsr colour_change

	; 4 - SPAWN FORMATION
1	lda #1
	bita keytable+4
	bne 1f
	clr en_spawn_count

1
 if DBG_RASTER
	lda #1
	anda keytable+2
	eora #1
	sta show_raster
 endif

1
	jsr rnd_number

	; bonus
	lda bonus_tmr
	beq 1f
	dec bonus_tmr
	bne 1f
	jsr [bonus_ptr]

1
	; housekeeping list
	ldu task_ptr
	ldx ,u++
	bne 1f
	ldu ,u
	ldx ,u++
1	stu task_ptr
	jsr ,x


	jmp MLOOP

end_level
	jsr warp_outro
	jsr pixel_fade
	jmp START_LEVEL

;*************************************

fl_mode_normal
	; draw non-collidable sprites
	jsr sp_update_non_collidable

	; player ship
	jsr draw_player

	; update player bullets (move, draw & save data for collision detect)
	jsr pb_update_all

	; draw collidable sprites
	jsr sp_update_collidable

	jsr player_collision

	jsr [control_set]

	; 3
1	lda #1
	bita keytable+3
	bne 1f
	ldx #sp_start_boss
	stx on_no_sprites
	ldd #task_table_nospawn
	std task_ptr

1	rts

;*************************************

fl_mode_boss
	jsr draw_player
	jsr pb_update_all
	jsr sp_update_collidable
	jsr player_collision
	jsr sp_update_non_collidable		; draw explosions on top of boss
	jsr [control_set]

	lda boss_hit
	beq 1f
	ldx boss_sprite
	beq 1f
	lda frmflag
	beq 1f

	bsr boss_explosion


	; 5
1	lda #1
	bita keytable+5
	bne 1f
	ldd #fl_mode_warp_out
	std mode_routine
	ldx #SND_WARPOUT
	jsr snd_start_fx_force

1	rts


; create explosion sprite at location of boss
boss_explosion
	ldu sp_free_list
	beq 1f
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_ncol_list	; add sprite to non-collidable list
	std SP_LINK,u		;
	stu sp_ncol_list	;
	inc sp_count		;

	ldd SP_XORD,x
	addd #-6*64		;missile_offset_x
	std SP_XORD,u
	ldd SP_YORD,x
	addd #-6*32		;missile_offset_y
	std SP_YORD,u
	clra
	clrb
	std SP_XVEL,u
	std SP_YVEL,u
	ldd #sp_player_expl_frames
	;ldd #sp_expl_frames
	std SP_FRAMEP,u
	ldd #sp_std_explosion
	std SP_DESC,u
1	rts

;*************************************

fl_mode_warp_out
	jsr draw_player
	jsr pb_update_all
	jsr sp_update_collidable

	lda player_dir
	inca
	anda #31
	sta player_dir
	cmpa #8
	beq 1f

	rts

1	jsr warp_outro
	jsr pixel_fade
	jsr colour_change

	lda lives
	adda #1
	daa
	sta lives

	lda en_std_max
	cmpa #CFG_NUM_SPRITES
	bhs 1f
	inc en_std_max

1	leas 2,s
	jmp START_LEVEL

;*************************************

fl_mode_death
	jsr sp_update_non_collidable
	jsr pb_update_all
	jsr sp_update_collidable

	lda death_tmr
	cmpa #35
	blo 1f
	;anda #1
	;bne 1f

	ldu sp_free_list
	beq 1f
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_ncol_list	; add sprite to non-collidable list
	std SP_LINK,u		;
	stu sp_ncol_list	;

	jsr player_explosion

1	dec death_tmr
	bne 1f

	jsr pixel_fade
	leas 2,s

	lda lives
	lbne NEXT_LIFE

	lda #TEXT_GREEN
	sta text_bg
	ldy #msg_game_over
	jsr draw_msg_front

	jsr wait_nokeys

	ldx #10000
5	jsr scan_keys
	jsr select_controls
	beq 2f
	leax -1,x
	bne 5b

2	jsr intro_restart

	ldx #colour_set_table_end-1		; initial palette
	jsr colour_change_x				;
	jmp RESTART_GAME

1	rts

;*************************************
; xabc pseudo-random number generator
; converted from c source found on www.eternityforest.com

	section "RAMCODE"

rnd_number
rndx lda #0
	inca
	sta rndx+1
rnda eora #0
rndc eora #0
	sta rnda+1
rndb adda #0
	sta rndb+1
	lsra
	adda rndc+1
	eora rnda+1
	sta rndc+1

	ldx rnd_ptr
	sta ,x+
	cmpx #rndtable_end
	blo 1f
	ldx #rndtable
1	stx rnd_ptr

	rts

;*************************************

	section "CODE"

task_table_normal
	fdb draw_lives
	fdb draw_lives
task_table_normal_rst
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb task_update_enemy
	fdb task_update_enemy
	fdb task_update_enemy
	fdb draw_score1
 	fdb draw_score0
	fdb draw_score2
	fdb task_update_enemy
	fdb task_update_enemy
	fdb task_update_enemy
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb task_update_enemy
	fdb task_update_enemy
	fdb task_update_enemy
	fdb draw_score1
	fdb draw_score0
	fdb draw_score2
	fdb task_update_enemy
	fdb task_update_enemy
	fdb task_update_enemy
	fdb en_spawn
	fdb 0, task_table_normal_rst


task_table_nospawn
	fdb draw_lives
	fdb draw_lives
task_table_nospawn_rst
	fdb check_no_sprites
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb task_update_enemy
	fdb 0, task_table_nospawn_rst

task_table_boss
	fdb draw_lives
	fdb draw_lives
task_table_boss_rst
	fdb check_no_sprites
	fdb task_update_boss
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb check_no_sprites
	fdb task_update_boss
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb 0, task_table_boss_rst


task_nop
	rts

;*************************************

	section "DPVARS"

on_no_sprites	rmb 2

	section "CODE"

check_no_sprites
	lda sp_count
	bne task_nop
	ldx on_no_sprites
	ldd #task_nop
	std on_no_sprites
	jmp ,x

;*************************************

LIVES_POS	equ 0-160

draw_lives
	ldu #LIVES_POS
	ldy #lives
	bra draw_digits


SCORE_POS	equ 25-160

draw_score2
	ldu #SCORE_POS
	ldy #score2
	bra draw_digits

draw_score1
	ldu #SCORE_POS+2
	ldy #score1
	bra draw_digits

draw_score0
	ldu #SCORE_POS+4
	ldy #score0
	;bra draw_digits

draw_digits
	ldd td_fbuf
	leau d,u
	ldb ,y
	andb #$f0
	lsrb
	bsr draw_digit
	leau 1,u
	ldb ,y
	andb #$f
	lslb
	lslb
	lslb
draw_digit
	ldx #chardata_digits
	abx
	ldd ,x
	sta -96,u
	stb -64,u
	ldd 2,x
	sta -32,u
	stb ,u
	ldd 4,x
	sta 32,u
	stb 64,u
	;lda 6,x
	;sta 96,u
	rts


;*************************************
; warp intro effect at start of level

warp_intro
	lda #128
	sta pw_speed
	clr pw_speed_acc
	ldd #6.5*32
	std pw_offset
	ldd #(PLYR_TOP*32)-16*32
	std pw_start
	clr pw_toggle

	ldx #SND_WARPIN
	jsr snd_start_fx_force

1	jsr pw_draw_warp
	ldx pw_start
	leax 16,x
	cmpx #(PLYR_TOP*32)
	bls 2f
	ldb #-20
	bra 3f
2	stx pw_start
	ldb #-4
3	sex
	addd pw_offset
	bmi 2f
	std pw_offset
	bra 1b
2	lda pw_speed
	suba #32
	sta pw_speed
	bne 1b

	ldx #SND_START
	jmp snd_start_fx_force


pw_speed		equ temp0		; byte
pw_speed_acc	equ temp1		; byte
pw_offset		equ temp2		; word
pw_offset_acc	equ temp4		; word
pw_start		equ temp6		; word
pw_toggle		equ temp8		; byte
pw_count		equ temp9		; byte
pw_temp			equ temp10		; byte


;*************************************
; warp out effect at end of level

warp_outro
	lda #32
	sta pw_speed
	clr pw_speed_acc
	clra
	clrb
	std pw_offset
	ldd #(PLYR_TOP*32)+14
	std pw_start
	clr pw_toggle

	;ldx #SND_WARPOUT
	;jsr snd_start_fx_force

	lda #104 ;96
	sta pw_count

1	jsr pw_draw_warp

	lda pw_speed
	adda #2
	cmpa #128
	bhi 2f
	sta pw_speed
2	cmpa #64
	blo 3f

	ldd pw_offset
	addd #3
	cmpd #7*32
	bge 3f
	std pw_offset
2
	ldd pw_start
	subd #9
	cmpd #-32*48
	blt 3f
	std pw_start
3
	dec pw_count
	lbne 1b

9	rts

;*************************************

pw_draw_warp
	jsr rnd_number
	jsr snd_update
	lda #8
	sta pw_temp
2	lda pw_speed_acc
	adda pw_speed
	sta pw_speed_acc
	bcc 3f
	jsr td_scroll_up
3	dec pw_temp
	bne 2b
	jsr td_copybuf

	ldx td_fbuf
	ldd pw_start
	andb #$e0
	orb #14		; move to middle
	leax d,x
	stx pw_offset_acc
	jsr pw_draw_player

	lda [snd_buf_ptr]
	sta $ff20
	inc snd_buf_ptr+1

	lda #8
	sta pw_temp
5	ldd pw_offset_acc
	addd pw_offset
	std pw_offset_acc
	andb #$e0
	orb #14		; move to middle
	tfr d,x
	com pw_toggle
	beq 6f
	jsr pw_draw_player
	lda [snd_buf_ptr]
	sta $ff20
	inc snd_buf_ptr+1
6	dec pw_temp
	bne 5b

	com pw_toggle

  if DBG_RASTER
	lda show_raster
	beq 90f
	TOGMODE
	TOGMODE
90
  endif

	jmp flip_frame_buffers_snd


;*************************************
; draw player ship pointing up

pw_draw_player
	lda #PLYR_HGT
	sta td_count
	ldu #sp_player+8*PLYR_SZ
	lda #32
	sta pdraw_inc
	jmp pdraw_general

;*************************************


	section "CODE"
__end_code

	section "DPVARS"
__end_dpvars

	section "DATA"
__end_data

	section "RAMCODE"
__end_ramcode_org

__end_ramcode_put	equ CFG_RAMCODE_PUT + (__end_ramcode_org - CFG_RAMCODE_ORG)

	section "SPRITE_DATA"
__end_sprite_data

	section "CYD_WAVES"
__end_cyd_waves


	end code_entry