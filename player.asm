;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "CODE"

PLYR_CTR_X	equ 63
PLYR_CTR_Y	equ ((TD_TILEROWS*8) >> 1) - 1
PLYR_HGT	equ 11
PLYR_LEFT	equ PLYR_CTR_X - 5
PLYR_TOP	equ PLYR_CTR_Y - (PLYR_HGT >> 1)
PLYR_SZ		equ PLYR_HGT*4

draw_player
	lda #PLYR_HGT
	sta td_count
	ldx td_fbuf

	lda player_dir
	anda #30
	ldu #player_frame_table
	ldu a,u
	stu pcol_src

	cmpa #16
	bhi 10f		; draw upside down

	ldb #32
	leax (PLYR_TOP*32)+14,x
	bra 20f
	
10	ldb #-32
	leax ((PLYR_TOP+PLYR_HGT-1)*32)+14,x

20	stb pdraw_inc
	lslb
	stb pcol_inc
	stx pcol_dst

pdraw_general	
1	pulu d
	anda ,x
	andb 1,x
	addd PLYR_HGT*4-2,u
	std ,x
	pulu d
	anda 2,x
	andb 3,x
	addd PLYR_HGT*4-2,u
	std 2,x
pdraw_inc equ *+2
	leax <32,x
	dec td_count
	bne 1b
	
	rts
	
;*************************************
player_collision

pcol_src equ *+1
	ldu #0
pcol_dst equ *+1
	ldx #FBUF0
	lda #(PLYR_HGT+1)/2
	sta td_count

1	pulu d
	coma
	comb
	anda ,x
	andb 1,x
	subd PLYR_HGT*4-2,u
	bne 20f
	pulu d
	coma
	comb
	anda 2,x
	andb 3,x
	subd PLYR_HGT*4-2,u
	bne 30f
pcol_inc equ *+2
	leax <32,x
	leau 4,u
	dec td_count
	bne 1b
	rts

30
20
	if DBG_NO_PLAYER_COL == 1
	rts
	endif
	
	ldu #sp_spare				; add spare sprite to free list
	ldd sp_free_list
	std SP_LINK,u
	stu sp_free_list
	
	ldu #sp_spare + SP_SIZE		; add 2nd spare sprite to non-collidable list
	ldd sp_ncol_list
	std SP_LINK,u
	stu sp_ncol_list

	bsr player_explosion

	lda lives
	adda #$99
	daa
	sta lives
	ldd #fl_mode_death
	std mode_routine
	ldd #exec_nop
	std on_no_sprites
	ldd #exec_table_nospawn
	std exec_ptr
	lda #50
	sta death_tmr
	ldx #SND_EXPL2
	jmp snd_start_fx
	
;*************************************

player_explosion
	ldb [rnd_ptr]
	sex
	addd #(PLYR_LEFT)*64
	std SP_XORD,u
	ldb [rnd_ptr+1]
	asrb
	sex
	addd #PLYR_TOP*32
	std SP_YORD,u
	clra
	clrb
	subd scroll_x
	std SP_XVEL,u
	clra
	clrb
	subd scroll_y
	std SP_YVEL,u
	clra
	clrb
	std SP_FRAME0,u
	ldd #sp_player_expl_frames
	std SP_FRAMEP,u
	ldd #sp_std_explosion
	std SP_DESC,u
	rts

;*************************************

move_player
	clra
	clrb
	std scroll_x
	std scroll_y

	if DBG_NO_PLAYER_MOVE
	rts
	endif
	
	ldb player_dir
	andb #30
	;ldx #player_speed_table
	;abx

	ldu #player_dir_table
	andb #24
	leau b,u
	stu 91f+1

	ldd scroll_x_ctr
	anda #$7f
	andb #$7f
	addd scroll_x_inc
	std scroll_x_ctr

	;tsta
	bpl 1f
	inc workload
	ldd 4,u
	std scroll_x
	jsr [,u]	;scroll left or right
	
1	lda scroll_y_ctr
	bpl 1f
	inc workload
91	ldu #0
	ldd 6,u
	std scroll_y
	jmp [2,u]		;scroll up or down
1	rts

;*************************************

PR1		equ 48  ;98
PR2		equ 90  ;181
PR3		equ 120 ;236
PR4		equ 128 ;256

player_speed_table
	fcb PR4,0		; E
	fcb PR3,PR1
	fcb PR2,PR2	; NE
	fcb PR1,PR3
	fcb 0, PR4		; N
	fcb PR1,PR3
	fcb PR2,PR2	; NW
	fcb PR3,PR1
	fcb PR4,0		; W
	fcb PR3,PR1
	fcb PR2,PR2	; SW
	fcb PR1,PR3
	fcb 0, PR4		; S
	fcb PR1,PR3
	fcb PR2,PR2	; SE
	fcb PR3,PR1

PVSX	equ 2*64/256
PVSY	equ 2*32/256
	
player_vel_table
	fcb  PR4*PVSX,  0			; E
	fcb  PR3*PVSX, -PR1*PVSY
	fcb  PR2*PVSX, -PR2*PVSY	; NE
	fcb  PR1*PVSX, -PR3*PVSY
	fcb  0,        -PR4*PVSY	; N
	fcb -PR1*PVSX, -PR3*PVSY
	fcb -PR2*PVSX, -PR2*PVSY	; NW
	fcb -PR3*PVSX, -PR1*PVSY
	fcb -PR4*PVSX,  0			; W
	fcb -PR3*PVSX,  PR1*PVSY
	fcb -PR2*PVSX,  PR2*PVSY	; SW
	fcb -PR1*PVSX,  PR3*PVSY
	fcb  0,         PR4*PVSY	; S
	fcb  PR1*PVSX,  PR3*PVSY
	fcb  PR2*PVSX,  PR2*PVSY	; SE
	fcb  PR3*PVSX,  PR1*PVSY


player_dir_table
	fdb td_scroll_right, td_scroll_up, -64, 32
	fdb td_scroll_left, td_scroll_up, 64, 32
	fdb td_scroll_left, td_scroll_down, 64, -32
	fdb td_scroll_right, td_scroll_down, -64, -32

player_frame_table
	fdb sp_player, sp_player+2*PLYR_SZ, sp_player+4*PLYR_SZ, sp_player+6*PLYR_SZ
	fdb sp_player+8*PLYR_SZ, sp_player+10*PLYR_SZ, sp_player+12*PLYR_SZ, sp_player+14*PLYR_SZ
	fdb sp_player+16*PLYR_SZ, sp_player+14*PLYR_SZ, sp_player+12*PLYR_SZ, sp_player+10*PLYR_SZ
	fdb sp_player+8*PLYR_SZ, sp_player+6*PLYR_SZ, sp_player+4*PLYR_SZ, sp_player+2*PLYR_SZ
	
;**********************************************************

	section "_STRUCT"
	org 0
	
PB_FLAG			rmb 1
PB_XORD			rmb 2
PB_YORD			rmb 2
PB_XVEL			rmb 2
PB_YVEL			rmb 2

PB_SIZE		equ *

;**********************************************************

	section "DATA"

pb_data0	rmb PB_SIZE * CFG_NUM_PB
pb_data_end	equ *

;**********************************************************

	section "CODE"


pb_init_all
	ldx #pb_data0
	ldy #pb_col_data
	clra
	ldu #pb_zero
1	sta PB_FLAG,x
	stu PB_COL_ADDR,y
	sta PB_COL_SAVE,y
	leax PB_SIZE,x
	leay PB_COL_SIZE,y
	cmpx #pb_data_end
	bne 1b
	rts

pb_zero	fcb 0

pb_fire
	ldy #pb_data0
1	lda PB_FLAG,y
	beq 10f
	leay PB_SIZE,y
	cmpy #pb_data_end
	blo 1b
	rts

10	ldx #player_vel_table
	ldb player_dir
	andb #30
	abx
	ldb ,x
	sex
	lslb
	rola
	lslb
	rola
	std PB_XVEL,y
	ldb 1,x
	sex
	lslb
	rola
	lslb
	rola
	std PB_YVEL,y

	addd #PLYR_CTR_Y*32
	addd PB_YVEL,y
	std PB_YORD,y

	ldd PB_XVEL,y
	lslb
	rola
	addd #PLYR_CTR_X*64
	std PB_XORD,y

	lda #1
	sta PB_FLAG,y

	ldx #SND_FIRE
	jmp snd_start_fx

	;rts

	

pb_update_all
	ldy #pb_data0
	ldu #pb_col_data

10	lda PB_FLAG,y
	beq 90f

	ldd PB_XORD,y
	addd PB_XVEL,y
	addd scroll_x
	blt 91f
	cmpa #31	;cmpd #127*64
	bhi 91f
	std PB_XORD,y

	;ldb PB_XORD+1,y
	lslb
	rola
	lslb
	rola
	anda #3
	ldx #pb_pixel_tab
	leax a,x

	ldd PB_YORD,y
	addd PB_YVEL,y
	addd scroll_y
	blt 91f
	cmpd #(SCRN_HGT-1)*32
	bhi 91f
	std PB_YORD,y

	;ldd PB_YORD,y		; y offset
	andb #$e0			; remove sub-pixel bits
	addb PB_XORD,y 		; x offset
	adda td_fbuf		; screen base
	std PB_COL_ADDR,u
	
	ldb ,x				; get pixel mask
	stb PB_COL_MASK,u
	eorb [PB_COL_ADDR,u]	;
	stb [PB_COL_ADDR,u]		; draw on screen
	andb ,x					; extract pixel for collision check
	stb PB_COL_SAVE,u
	
90	leay PB_SIZE,y
	leau PB_COL_SIZE,u
	cmpy #pb_data_end
	blo 10b
	
	rts

91	clra
	sta PB_FLAG,y
	sta PB_COL_SAVE,u
	ldx #pb_zero
	stx PB_COL_ADDR,u
	bra 90b


pb_pixel_tab
	fcb $c0, $30, $0c, $03
