;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************


	include "stdmacros.asm"

DBG_RASTER 			equ 1
;DBG_NO_PLAYER_COL	equ 1
;DBG_NO_PLAYER_MOVE	equ 1
;DBG_SKIP_INTRO		equ 1

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

; start of code
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

; address of run-once throw away code
;CFG_RUN_ONCE_ADDR	equ CFG_SBUFF
CFG_RUN_ONCE_ADDR	equ $5400

; address of code that needs be copied to RAM
CFG_RAMCODE_PUT		equ __end_run_once

; destination address of code copied to RAM
CFG_RAMCODE_ORG		equ __end_data


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
exec_ptr		rmb 2
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

	include "grfx/charset.asm"

draw_strz
2	ldb ,y+
	beq 1f
	subb #64
	lda #5
	mul
	bsr draw_char
	leau 1,u
	bra 2b
	
draw_char
	ldx #charset
	abx
	ldd ,x
	sta -64,u
	stb -32,u
	ldd 2,x
	sta ,u
	stb 32,u
	lda 4,x
	sta 64,u
1	rts

msg_game_over	fcc "GAME@OVER@PUNY@HUMAN",0
msg_restart		fcc "SPACE@OR@FIRE@TO@PLAY@AGAIN",0
	
;**********************************************************

	section "RUN_ONCE"
	
	org CFG_RUN_ONCE_ADDR

	include "rotb_tune.asm"

	
code_entry
	;orcc #$50
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
	
	ldu #CFG_RAMCODE_PUT
	ldx #CFG_RAMCODE_ORG
1	lda ,u+
	sta ,x+
	cmpx #__end_ramcode_org
	blo 1b
	
	lda #DPVARS >> 8
	tfr a,dp
	setdp DPVARS >> 8

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


	jmp START_GAME

	include "intro.asm"

	
;**********************************************************
	
	section "CODE"

	setdp DPVARS >> 8

	org CFG_CODE_ADDR

	include "grfx/tiledata.asm"
	include "grfx/sp_test.asm"
	include "grfx/sp_explosion.asm"
	include "grfx/sp_flap.asm"
	include "grfx/sp_player.asm"
	include "grfx/chardata_digits.asm"
	include "player.asm"
	include "sprite_desc.asm"
	include "sprites.asm"
	include "enemies.asm"
	include "sound.asm"
	include "colour_change.asm"
	include "controls.asm"

TD_SBUFF	equ CFG_SBUFF		; start of shift buffers
TD_TILEROWS	equ CFG_TILEROWS	; number of rows of tiles

	include "tiledriver.asm"

START_GAME
	
	ldd #$aaaa				; prefill shift buffers
	ldx #TD_SBUFF
1	std ,x++
	cmpx #TD_SBEND
	blo 1b

RESTART_GAME
	
	lda #4
	sta en_std_max
	lda #CFG_LIVES
	sta lives
	clra
	clrb
	std score2
	sta score0
	
START_LEVEL
	clr en_count
	
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

	ldd #fl_mode_normal
	std mode_routine
	ldd #exec_table_normal
	std exec_ptr
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
	
	; draw non-collidable sprites
	jsr sp_update_non_collidable

	jsr scan_keys

	jsr [mode_routine]

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
  
	jsr flip_frame_buffers


	; 1 - CHANGE COLOUR SET
1	lda #1
	bita keytable+1
	bne 1f
	jsr colour_change

	; 4
1	;lda #1
	;bita keytable+4
	;bne 1f
	;ldx #SND_TONE4
	;jsr snd_start_fx_force

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
	ldu exec_ptr
	ldx ,u++
	bne 1f
	ldu ,u
	ldx ,u++
1	stu exec_ptr
	jsr ,x
	
	
	jmp MLOOP

end_level
	jsr warp_outro
	jsr pixel_fade
	jmp START_LEVEL
	
;*************************************

fl_mode_normal
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
	ldd #fl_mode_warp_out
	std mode_routine
	ldx #SND_WARPOUT
	jsr snd_start_fx_force

1	rts


fl_mode_warp_out
	; player ship
	jsr draw_player
	
	; update player bullets (move, draw & save data for collision detect)
	jsr pb_update_all
	
	; draw collidable sprites
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
	

fl_mode_death
	; update player bullets (move, draw & save data for collision detect)
	jsr pb_update_all
	
	; draw collidable sprites
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

	ldd td_fbuf
	eora #FBUF_TOG_HI
	addd #32*32+5
	tfr d,u
	ldy #msg_game_over
	jsr draw_strz
	
	ldd td_fbuf
	eora #FBUF_TOG_HI
	addd #48*32+2
	tfr d,u
	ldy #msg_restart
	jsr draw_strz

	
5	jsr scan_keys
	jsr select_controls
	bne 5b

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

exec_table_normal
	fdb draw_lives
	fdb draw_lives
exec_table_normal_rst
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb draw_score1
 	fdb draw_score0
	fdb draw_score2
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb draw_score1
	fdb draw_score0
	fdb draw_score2
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb exec_update_enemy
	fdb en_spawn
	fdb 0, exec_table_normal_rst


exec_table_nospawn
	fdb draw_lives
	fdb draw_lives
exec_table_nospawn_rst
	fdb check_no_sprites
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb draw_score2
	fdb draw_score1
	fdb draw_score0
	fdb exec_update_enemy
	fdb 0, exec_table_nospawn_rst
	
exec_nop
	rts

;*************************************

	section "DPVARS"

on_no_sprites	rmb 2

	section "CODE"

check_no_sprites
	lda sp_count
	bne exec_nop
	ldx on_no_sprites
	ldd #exec_nop
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
; Swap front and back frame buffers
;*************************************

flip_frame_buffers
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

	jmp flip_frame_buffers

	
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

pf_tog		equ temp0
pf_fcount	equ temp1
pf_vcount	equ temp2

pixel_fade
	jsr snd_clear_buf
	
	; copy displayed screen to backbuffer
	; so display doesn't jump up and down
	ldd td_fbuf
	tfr d,x
	eora #FBUF_TOG_HI	; get address of other buffer
	tfr d,u
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
	
	ldx #soundbuf		; reset sound buffer pointer
	stx snd_buf_ptr		; (flip_frame_buffers generates sound)

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

; 1st byte is row offset, 2nd byte is mask
	;fcb 0,$3f,2,$f3,0,$f3,2,$3f
	;fcb 1,$cf,3,$fc,1,$fc,3,$cf
	;fcb 0,$cf,2,$fc,0,$fc,2,$cf
	;fcb 1,$3f,3,$f3,1,$f3,3,$3f

; ordered dither matrix
; 1  9  3 11
;13  5 15  7
; 4 12  2 10
;16  8 14  6
	
;*************************************
	
	section "CODE"
__end_code

	section "RUN_ONCE"
__end_run_once

	section "DPVARS"
__end_dpvars

	section "DATA"
__end_data

	section "RAMCODE"
__end_ramcode_org

__end_ramcode_put	equ CFG_RAMCODE_PUT + (__end_ramcode_org - CFG_RAMCODE_ORG)

	section "SPRITE_DATA"
__end_sprite_data

	end code_entry