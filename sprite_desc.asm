;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************


; RAM based-sprite descriptor

	section "_STRUCT"
	org 0

SP_XORD		rmb 2	; x * 64
SP_YORD		rmb 2	; y * 32
SP_XVEL		rmb 2	; x velocity * 64
SP_YVEL		rmb 2	; y velocity * 32

SP_FRAMEP	rmb 2	; pointer to current frame
SP_MISFLG	rmb 1	; missile flag: 0 = not-trackable, -ve = trackable, +ve = tracking
SP_COLFLG	rmb 1
SP_UPDATEP	rmb 2	; pointer to update code
SP_DESC		rmb 2	; pointer to additional (constant) info
SP_DATA		rmb 1	; type dependent data
SP_DATA2	rmb 1	; type dependent data
SP_DATA3	rmb 1	; type dependent data
SP_LINK		rmb 2	; pointer to next sprite in list

SP_SIZE		equ *	; size of data structure


; Constant part of sprite descriptor
; Can be ROM resident

	org 0

SP_OFFSCR	rmb 2	; pointer to offscreen handler
SP_EXPL		rmb 2	; pointer to explosion sound effect
SP_SCORE	rmb 1	; score
SP_DPTR		rmb 2	; pointer to code to run on death
SP_MISCODE	rmb 2	; pointer to code to run on missile hit

SP_DESC_SIZE	equ *	; size of data structure

;**********************************************************

	section "CODE"

;----------------------------------------------------------
; standard enemy

sp_std_desc
1	fdb sp_remove		; offscreen handler
	fdb SND_EXPL_S		; explosion sound
	fcb 1			; score 10
	fdb sp_std_hit		; on destroy
	fdb sp_rts		; missile hit n/a
	assert (*-1b) == SP_DESC_SIZE, "sp_std_desc wrong_size"

	; on hit check if player has destroyed enough enemies
sp_std_hit
	inc en_count
	lda en_count
	cmpa #50
	blo 1f
	ldx #sp_start_boss
	cmpx on_no_sprites
	beq 1f
	stx on_no_sprites
	ldd #task_table_nospawn
	std task_ptr
	ldx #SND_ALERT2
	jsr snd_start_fx_force
1	jmp sp_dptr_rtn		; return to caller


sp_warp
	ldd #fl_mode_warp_out
	std mode_routine
	ldx #SND_WARPOUT
	jmp snd_start_fx_force



sp_std_update_init
	ldb player_dir
	andb #30
	lslb
	stb SP_DATA,y		; direction
	lslb
	ldx #form_coords
	abx
	ldb en_spawn_param
	leax b,x
	addb #16
	stb en_spawn_param
	ldd ,x
	std SP_XORD,y
	ldd 2,x
	std SP_YORD,y
	clra
	clrb
	std SP_XVEL,y
	std SP_YVEL,y
	dec SP_MISFLG,y		; missile target
	clr SP_COLFLG,y		;
	lda #16			; number of updates spent chasing player
	sta SP_DATA2,y		;
	lda #1			; 1st update next frame
	sta SP_DATA3,y		;
	ldd #sp_std_img
	std SP_FRAMEP,y
	ldd #sp_std_desc
	std SP_DESC,y
	ldd #sp_std_update
	std SP_UPDATEP,y
	jmp sp_update_sp4x12_next


dx	equ temp0
dy	equ temp1
sp_dir	equ temp2

sp_std_update
	dec SP_DATA3,y
	bne 9f
	lda #4
	sta SP_DATA3,y
	lda #4		; chase player
	dec SP_DATA2,y
	bpl 1f
	nega		; run away
1	sta sp_dir

	ldd SP_XORD,y			; subtract player coord x
	subd #(PLYR_LEFT*64)
	;lslb
	;rola
	lslb
	rola
	sta dx
	ldd #(PLYR_TOP*32)		; subtract from player coord y
	subd SP_YORD,y			; (screen coords are upside down)
	;lslb
	;rola
	lslb
	rola
	lslb
	rola
	sta dy

	ldb #4		; determine octant
	lda dy		;
	bpl 1f		; y >= 0
	neg dx		; rotate 180 cw
	neg dy		;
	addb #4*8	;
1	lda dx		;
	bpl 1f		; x >= 0
	nega		; rotate 90 cw
	ldx dy   	; don't care about low byte
	stx dx    	;  just need to swap dx & dy
	sta dy		;
	lda dx		;
	addb #2*8	;
1	cmpa dy		;
	bhs 1f		; x >= y
	addb #1*8	;

	; determine which direction to rotate
1	lda sp_dir	;
	subb SP_DATA,y	; difference in directions
	bne 1f		; not pointing at player, so turn
	tsta		; chasing or running away?
	bmi 3f		; running away, so turn 
	clra		; direction is correct, don't turn
	bra 3f		;

1	bpl 1f		; select the faster turn direction
	nega		;
	negb		;
1	cmpb #32	;
	blo 3f		;
	nega		;

3	adda SP_DATA,y
	anda #$3c
	sta SP_DATA,y
	ldx #std_enemy_vel_table
	leax a,x
	ldd ,x
	std SP_XVEL,y
	ldd 2,x
	std SP_YVEL,y

9	jmp sp_update_sp4x12

sp_rts
	rts


; standard enemy velocity table
std_enemy_vel_table
	mac_velocity_table_180 0.8

;----------------------------------------------------------
; formation enemy

sp_form_desc
1	fdb sp_form_offscreen	; offscreen handler
	fdb SND_EXPL_F		; explosion sound
	fcb 2			; score 20
	fdb sp_form_hit		; on destroy
	fdb sp_rts		; missile hit n/a
	assert (*-1b) == SP_DESC_SIZE, "sp_form_enemy wrong size"

sp_form_update_init
	ldb player_dir
	andb #30
	lslb
	ldu #form_enemy_vel_table
	leau b,u
	lslb
	ldx #form_coords
	abx
	ldb en_spawn_param
	leax b,x
	addb #4
	bne 1f			; create gap in middle of formation
	addb #4			; where player is facing
1	stb en_spawn_param
	ldd ,x
	std SP_XORD,y
	ldd 2,x
	std SP_YORD,y
	ldd ,u
	std SP_XVEL,y
	ldd 2,u
	std SP_YVEL,y
	;clr SP_MISFLG,y
	clr SP_COLFLG,y
	ldd #sp_form_desc
	std SP_DESC,y
	ldd #sp_form_img
	std SP_FRAMEP,y
	ldd #sp_form_update
	std SP_UPDATEP,y
	jmp sp_update_sp4x12_next


sp_form_ps_params
	fcb 3		; number of sprites to preshift
	fdb sp_form_img	; destination
	fdb sp_flap_2	; source
	fcb 4		; frame sync count


sp_form_update
	ldd SP_FRAMEP,y
	addd #384
	cmpd #sp_form_img+3*384
	blo 2f
	ldd #sp_form_img
2	std SP_FRAMEP,y
	jmp sp_update_sp4x12
	
	; on hit check if player has destroyed whole formation
sp_form_hit
	dec en_form_count
	bne 1f

	ldx #bonus_form
	stx bonus_ptr
	lda #8
	sta bonus_tmr

1	jmp sp_dptr_rtn			; return to caller


bonus_form
	lda score1
	adda #1
	daa
	sta score1
	lda score2
	adca #0
	daa
	sta score2

	inc kill_count
	lda kill_count
	anda #3
	lsla
	ldx #SND_FX_TAB
	ldx a,x
	jmp snd_start_fx


; formation enemy velocity table
form_enemy_vel_table
	mac_velocity_table_180 1.1

;----------------------------------------------------------
; standard explosion

sp_std_explosion
1	fdb sp_remove		; offscreen handler
	fdb 0			; explosion sound n/a
	fcb 0			; score n/a
	fdb sp_dptr_rtn		; destruction code n/a
	fdb sp_rts		; missile hit n/a
	assert (*-1b) == SP_DESC_SIZE, "sp_std_explosion wrong size"

sp_plyr_expl_update_init
	ldu #sp_player_expl_frames
	bra 1f
sp_std_expl_update_init
	ldu #sp_expl_frames
1	stu SP_DATA,y
	ldd #sp_std_explosion
	std SP_DESC,y
	ldd #sp_std_expl_update
	std SP_UPDATEP,y
	jmp sp_update_sp4x12_next

sp_std_expl_update
	ldu SP_DATA,y
	ldd ,u++
	lbeq sp_remove
	stu SP_DATA,y
	std SP_FRAMEP,y
	jmp sp_update_sp4x12

;----------------------------------------------------------
; boss

	section "DPVARS"

boss_sprite		rmb 2	; address of first boss sprite
boss_sprite_last	rmb 2	; address of last boss sprite
boss_hit		rmb 1	; flag that boss has been hit by player missile


	section "CODE"

sp_boss_desc
1	fdb sp_boss_offscreen	; offscreen handler
	fdb SND_EXPL2		; explosion sound
	fcb 0			; score n/a
	fdb sp_dptr_rtn		; destruction code n/a
	fdb sp_boss_on_missile	; missile hit code
	assert (*-1b) == SP_DESC_SIZE, "sp_boss_desc wrong size"

sp_boss_ps_params
	fcb 4		; number of sprites to preshift
	fdb sp_boss_img	; destination
	fdb sp_boss	; source
	fcb 0		; frame sync count

; initialise boss just off edge of screen behind player
; boss is made up of four sprites flying in formation
; assumes there are four free sprites
sp_start_boss
	ldd #fl_mode_boss
	std mode_routine
	ldx #sp_warp
	stx on_no_sprites
	clr boss_hit
	ldd #-64*6
	std missile_offset_x
	ldd #-32*6
	std missile_offset_y
	ldd #sp_boss_init_params
	std en_spawn_param

	ldd #sp_boss_ps_params	; graphics preshift params
	jsr en_update_ps_setup	; prepare for preshift
	ldy #sp_boss_update_initb	; address of initialiser
	jsr en_new_sprite
	stu boss_sprite_last	; keep address for removal routine
	jsr en_new_sprite
	jsr en_new_sprite
	ldy #sp_boss_update_inita	; address of initialiser
	jsr en_new_sprite
	stu boss_sprite		; keep address for update routines
	rts


; boss off-screen handler
; if boss has been hit then remove
; else limit coords to just out of view.
sp_boss_offscreen
	lda boss_hit		; If boss has been hit then we need to
	beq 1f			; remove sprites when they go off screen.
	cmpy boss_sprite	; Wait until we're looking at first sprite in list.
	beq 2f			;
3	jmp sp_update_sp4x12_next
1	cmpy boss_sprite_last	; Waiting for last sprite so that modified
	bne 3b			; coords don't get overwritten by update routine

; stop boss going any further than just off edge of screen
	lda SP_XORD,y
	cmpd #-24*64
	bge 3f
	ldd #-24*64
	bsr sp_boss_update_x
	bra 4f
3	cmpd #128*64
	ble 4f
	ldd #128*64
	bsr sp_boss_update_x
4	ldd SP_YORD,y
	cmpd #-24*32
	bge 5f
	ldd #-24*32
	bsr sp_boss_update_y
	bra 6f
5	cmpd #(SCRN_HGT)*32
	ble 6f
	ldd #(SCRN_HGT)*32
	bsr sp_boss_update_y
6	jmp sp_update_sp4x12_next


; remove boss when off screen
2	lda SP_XORD,y
	cmpa #-2
	blt 1f
	cmpa #34
	bgt 1f
	ldd SP_YORD,y
	cmpd #-12*32
	blt 1f
	cmpd #(SCRN_HGT+12)*32
	bge 1f
	jmp sp_update_sp4x12_next

1	clra
	clrb
	std boss_sprite		; sprite is no longer valid
	clr SP_MISFLG,y
	bsr sp_boss_remove
	bsr sp_boss_remove
	bsr sp_boss_remove
	jmp sp_remove

; remove one boss sprite
sp_boss_remove
	dec sp_count		; reduce sprite count
	ldu sp_prev_ptr		; remove sprite from current list
	ldd SP_LINK,y		;
	std SP_LINK,u		;
	ldd sp_free_list	; add sprite to free list
	std SP_LINK,y		;
	sty sp_free_list	;
	ldy SP_LINK,u		; next sprite
	rts

; write x coord to all boss sprites
sp_boss_update_x
	std SP_XORD,y
	ldu boss_sprite
	addd #12*64
	std SP_XORD,u
	ldu SP_LINK,u
	subd #12*64
	std SP_XORD,u
	ldu SP_LINK,u
	addd #12*64
	std SP_XORD,u
	rts

; write y coord to all boss sprites
sp_boss_update_y
	std SP_YORD,y
	ldu boss_sprite
	addd #12*32
	std SP_YORD,u
	ldu SP_LINK,u
	std SP_YORD,u
	ldu SP_LINK,u
	subd #12*32
	std SP_YORD,u
	rts


sp_boss_update_inita
	dec SP_MISFLG,y		; main sprite can be targeted
	ldb player_dir
	stb SP_DATA2,y
	ldx #sp_boss_update
	bra 1f
sp_boss_update_initb
	ldb player_dir
	ldx #sp_update_sp4x12
1	stx SP_UPDATEP,y
	addb #16		; add 180 degrees to player dir
	lslb			;
	andb #$3c		;
	ldx #boss_coords	; boss init coords table
	abx			;
	lslb			;
	lslb			;
	stb SP_DATA,y		; initial direction
	clra			; start with zero velocity
	clrb			;
	std SP_XVEL,y		;
	std SP_YVEL,y		;
	sta SP_COLFLG,y		; init collision flag
	ldd #sp_boss_desc
	std SP_DESC,y
	ldu en_spawn_param
	pulu d
	addd ,x
	std SP_XORD,y
	pulu d
	addd 2,x
	std SP_YORD,y
	pulu d
	std SP_FRAMEP,y
	stu en_spawn_param
	jmp sp_update_sp4x12_next

; initialisation table for each sprite making up the boss
; contains coord offsets and graphics address
sp_boss_init_params
	fdb 12*64, 12*32, sp_boss_img+3*384
	fdb 0,     12*32, sp_boss_img+2*384
	fdb 12*64, 0,     sp_boss_img+384
	fdb 0,     0,     sp_boss_img


; boss behaviour:
; steer toward centre of screen
; with modification to steer behind player as they turn
sp_boss_update
	lda #4		; chase player
	ldb boss_hit
	beq 1f
	nega		; run away
1	sta sp_dir

	ldd SP_XORD,y		; calculate distance of boss from player
	subd #(PLYR_LEFT*64)
	addd #-6*64		; adjustment to allow for size of boss
	lslb
	rola
	lslb
	rola
	sta dx
	ldd #(PLYR_TOP*32)
	subd SP_YORD,y
	subd #-6*32		; adjustment to allow for size of boss
	lslb
	rola
	lslb
	rola
	lslb
	rola
	sta dy

	ldb #16		; determine octant
	lda dy		;
	bpl 1f		; y >= 0
	neg dx		; rotate 180 cw
	neg dy		;
	addb #4*32	;
1	lda dx		;
	bpl 1f		; x >= 0
	nega		; rotate 90 cw
	ldx dy   	; don't care about low byte
	stx dx    	;  just need to swap dx & dy
	sta dy		;
	lda dx		;
	addb #2*32	;
1	cmpa dy		;
	bhs 1f		; x >= y
	addb #1*32	;

	; determine which direction to rotate
1	lda sp_dir	;
	subb SP_DATA,y	; calc difference in directions
	bne 1f		; direction not equal
	tsta		; chasing or fleeing?
	bmi 3f		; fleeing, so need to turn
	clra		; chasing, so no need to turn
	bra 3f		;
1	bpl 3f		; turning in correct direction
	nega		; turn the other way

	; modification #1: slow down boss when nearer to player
	; dx & dy are already positive
3	ldx #sp_boss_vel_table
	ldb dx
	cmpb dy
	bhi 4f
	lsrb
	addb dy
	bra 5f
4	lsr dy
	addb dy
5	cmpb #40
	bhi 6f
	leax 64,x		; reduced velocity when nearer to player
	asra			; also reduced turn rate

	; modification #2: input a proportion of player steering
6	sta temp0
	lda SP_DATA2,y
	suba player_dir
	lsla
	lsla
	adda temp0
	ldb player_dir	; save player_dir for next time
	stb SP_DATA2,y	;

	adda SP_DATA,y
	sta SP_DATA,y	; new direction
	lsra
	lsra
	anda #$3c
	leax a,x
	ldd ,x
	std SP_XVEL,y
	ldd 2,x
	std SP_YVEL,y
	ldu SP_LINK,y
	ldd ,x
	std SP_XVEL,u
	ldd 2,x
	std SP_YVEL,u
	ldu SP_LINK,u
	ldd ,x
	std SP_XVEL,u
	ldd 2,x
	std SP_YVEL,u
	ldu SP_LINK,u
	ldd ,x
	std SP_XVEL,u
	ldd 2,x
	std SP_YVEL,u

9	jmp sp_update_sp4x12


; code to run when missile hits boss
sp_boss_on_missile
	inc boss_hit
	clr SP_MISFLG,u
	;ldx #SND_EXPL2
	ldx SP_EXPL,x
	jsr snd_start_fx
	ldx boss_sprite
	jmp boss_explosion


; boss velocity table
sp_boss_vel_table
	mac_velocity_table_180 1.5
	mac_velocity_table_180 1.25


;**********************************************************

sp_expl_frames
	fdb sp_explosion_img
	fdb sp_explosion_img+1*384
	fdb sp_explosion_img
	fdb sp_explosion_img+2*384
	fdb sp_explosion_img
	fdb sp_explosion_img+1*384
	fdb sp_explosion_img+2*384
	fdb sp_explosion_img+2*384
	fdb sp_explosion_img+3*384
	fdb 0

sp_player_expl_frames
	fdb sp_explosion_img+3*384
	fdb sp_explosion_img+2*384
	fdb sp_explosion_img+1*384
	fdb sp_explosion_img
	fdb sp_explosion_img+1*384
	fdb sp_explosion_img
	fdb sp_explosion_img+1*384
	fdb sp_explosion_img+2*384
	fdb sp_explosion_img+3*384
	fdb 0,0


