;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************


; RAM based-sprite descriptor

	section "_STRUCT"
	org 0
	
SP_FRAMEP	rmb 2	; pointer to current frame or 0 if single frame
SP_FRAME0	rmb 2	; start of frame list / single frame addr / 0 if list plays once
SP_XORD		rmb 2	; x * 64
SP_YORD		rmb 2	; y * 32
SP_XVEL		rmb 2	; x velocity * 64
SP_YVEL		rmb 2	; y velocity * 32
SP_DESC		rmb 2	; pointer to additional (constant) info
SP_DATA		rmb 1	; type dependent data
SP_DATA2	rmb 1	; type dependent data
SP_LINK		rmb 2	; pointer to next sprite in list

SP_SIZE		equ *	; size of data structure


; Constant part of sprite descriptor
; Can be ROM resident

	org 0

SP_OFFSCR	rmb 2	; pointer to offscreen handler
SP_EXPL		rmb 2	; pointer to explosion sound effect
SP_SCORE	rmb 1	; score
SP_UPDATE	rmb 2	; pointer to update handler
SP_DPTR		rmb 2	; pointer to code to run on death (or zero)

;**********************************************************

	section "CODE"

; constant descriptor info for sprites
	
;----------------------------------------------------------
; standard enemy

sp_std_enemy
	fdb sp_remove		; offscreen handler
	fdb SND_EXPL_S		; explosion sound
	fcb 1				; score 10
	fdb sp_std_update
	fdb sp_std_hit		; on hit...

	; ...check if player has destroyed enough enemies
sp_std_hit
	inc en_count
	lda en_count
	cmpa #50
	blo 1f
	ldx #sp_warp
	cmpx on_no_sprites
	beq 1f
	stx on_no_sprites
	ldd #exec_table_nospawn
	std exec_ptr
	ldx #SND_ALERT2
	jsr snd_start_fx_force
1	jmp sp_dptr_rtn			; return to caller

sp_warp
	ldd #fl_mode_warp_out
	std mode_routine
	ldx #SND_WARPOUT
	jmp snd_start_fx_force


dx		equ temp0
dy		equ temp1
sp_dir	equ temp2

sp_std_update
	lda #4		; chase player
	dec SP_DATA2,u
	bpl 1f
	nega		; run away
1	sta sp_dir

	ldd SP_XORD,u			; subtract player coord x
	subd #(PLYR_LEFT*64)
	;lslb
	;rola
	lslb
	rola
	sta dx
	ldd #(PLYR_TOP*32)		; subtract from player coord y
	subd SP_YORD,u			; (screen coords are upside down)
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
1	lda sp_dir
	subb SP_DATA,u
	;beq sp_rts
	bne 1f
	tsta
	bpl sp_rts
	bra 3f
1	bpl 1f
	nega
	negb
1	cmpb #32
	blo 3f
	nega

3	adda SP_DATA,u
	anda #$3c
	sta SP_DATA,u
	ldx #enemy_vel_table
	leax a,x
	ldd ,x
	std SP_XVEL,u
	ldd 2,x
	std SP_YVEL,u
sp_rts
	rts


	
;----------------------------------------------------------
; formation enemy	

sp_form_enemy
	fdb sp_form_offscreen	; offscreen handler
	fdb SND_EXPL_F			; explosion sound
	fcb 2					; score 20
	fdb sp_rts				; update handler n/a
	fdb sp_form_hit			; on hit...
	
	; ...check if player has destroyed whole formation
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

;----------------------------------------------------------
; standard explosion

sp_std_explosion
	fdb sp_remove		; offscreen handler
	fdb 0				; explosion sound n/a
	fcb 0				; score n/a
	fdb sp_rts			; update handler n/a
	fdb sp_dptr_rtn		; destruction code n/a
	
;**********************************************************
	
sp_expl_frames
	fdb sp_explosion_img
	fdb sp_explosion_img+1*384
	fdb sp_explosion_img
	fdb sp_explosion_img+1*384
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
	fdb 0

sp_flap_frames
	fdb sp_flap_img
	fdb sp_flap_img+1*384
	fdb 0
