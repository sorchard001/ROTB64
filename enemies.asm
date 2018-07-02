;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "DPVARS"

en_std_max	rmb 1	; max number of standard enemies
en_spawn_count	rmb 1	; counts number of standard enemies spawned vs formations
en_form_count	rmb 1	; counts number of enemies remaining to be in formation
en_count	rmb 1	; counts number of enemies destroyed
en_spawn_ptr	rmb 2	; points to spawn coords


	section "CODE"

; formation spawn rate
EN_FORM_PERIOD equ 8

en_init_all
	lda #EN_FORM_PERIOD
	sta en_spawn_count
	;clr en_count
	;lda #3
	;sta en_std_max
	rts


en_sprite_init_form
	ldu sp_free_list	; get next free sprite
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_pcol_list	; add sprite to collidable list
	std SP_LINK,u		;
	stu sp_pcol_list	;
	inc sp_count
	ldd ,y
	std SP_XVEL,u
	ldd 2,y
	std SP_YVEL,u
	clr SP_MISFLG,u
	clr SP_COLFLG,u

	ldd #sp_form_update_init
	std SP_UPDATEP,u
9	rts


en_spawn
	; calculate spawn coords based on player direction
	ldb player_dir
	andb #30
	lslb
	ldy #form_enemy_vel_table	; calculate formation velocity
	leay b,y					;
	lslb
	ldx #form_coords
	abx

	lda en_spawn_count	; time to spawn formation yet?
	bne 1f				; spawn standard enemy

; spawn enemy formation
	lda sp_count		; enough free sprites to spawn formation?
	cmpa #CFG_NUM_SPRITES-4	;
	bhi 9b				; not enough - rts

	lda #EN_FORM_PERIOD
	sta en_spawn_count
	lda #4
	sta en_form_count

	bsr en_sprite_init_form
	ldd -8,x
	std SP_XORD,u
	ldd -6,x
	std SP_YORD,u
	bsr en_sprite_init_form
	ldd -4,x
	std SP_XORD,u
	ldd -2,x
	std SP_YORD,u
	bsr en_sprite_init_form
	ldd 4,x
	std SP_XORD,u
	ldd 6,x
	std SP_YORD,u
	bsr en_sprite_init_form
	ldd 8,x
	std SP_XORD,u
	ldd 10,x
	std SP_YORD,u

	ldx #SND_ALERT
	jmp snd_start_fx

; spawn standard enemy
1	lda en_std_max
	suba #2
	cmpa sp_count
	blo 9f
	stx en_spawn_ptr
	dec en_spawn_count
	bsr en_sprite_init_std
en_sprite_init_std
	ldu sp_free_list	; get next free sprite
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_pcol_list	; add sprite to collidable list
	std SP_LINK,u		;
	stu sp_pcol_list	;
	inc sp_count
	ldd #sp_std_enemy_update_init
	std SP_UPDATEP,u
9	rts


;-----------------------------------------------------------

; standard enemy velocity table
std_enemy_vel_table
	mac_velocity_table_180 0.8

; formation enemy velocity table
form_enemy_vel_table
	mac_velocity_table_180 1.1



	include "coords.asm"
