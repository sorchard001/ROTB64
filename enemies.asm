;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "DPVARS"

en_std_max		rmb 1	; max number of standard enemies
en_spawn_count	rmb 1	; counts number of standard enemies spawned vs formations
en_form_count	rmb 1	; counts number of enemies remaining to be in formation
en_count		rmb 1	; counts number of enemies destroyed
en_update_ptr	rmb 2

	
	section "CODE"

; formation spawn rate
EN_FORM_PERIOD equ 8
	
en_init_all
	lda #EN_FORM_PERIOD
	sta en_spawn_count
	ldd #sp_data
	std en_update_ptr
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

	ldd #sp_flap_frames
	std SP_FRAMEP,u
	std SP_FRAME0,u

	;ldd #sp_flap_img
	;std SP_FRAME0,u
	;ldd #0
	;std SP_FRAMEP,u
	
	ldd #sp_form_enemy
	std SP_DESC,u
9	rts


en_spawn
	; calculate spawn coords & velocity based on player direction
	ldb player_dir
	andb #30
	lslb
	ldy #enemy_vel_table
	leay b,y
	lslb
	ldx #form_coords
	abx

	lda en_spawn_count		; time to spawn formation yet?
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
	
	;lda sp_count			; enough free sprites?
	;cmpa #CFG_NUM_SPRITES-2	;
	;bhi 9f					; not enough - rts

	;lda [rnd_ptr]
	;anda #8
	;suba #4
	;leax a,x
	lsrb
	bsr en_sprite_init_std
	ldd -8,x
	std SP_XORD,u
	ldd -6,x
	std SP_YORD,u
	ldb SP_DATA,u
	bsr en_sprite_init_std
	ldd 8,x
	std SP_XORD,u
	ldd 10,x
	std SP_YORD,u

	dec en_spawn_count
	
9	rts


en_sprite_init_std
	ldu sp_free_list	; get next free sprite
	stb SP_DATA,u		; angle
	lda #3
	;lda [rnd_ptr]
	;anda #1
	;inca				; number of updates spent steering towards player 
	sta SP_DATA2,u		;
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
	ldd #sp_test_img
	std SP_FRAME0,u
	ldd #0
	std SP_FRAMEP,u
	ldd #sp_std_enemy
	std SP_DESC,u
	rts
	
	
exec_update_enemy
	ldu en_update_ptr
	leau SP_SIZE,u
	cmpu #sp_data_end
	blo 1f
	ldu #sp_data
1	stu en_update_ptr
	ldx SP_DESC,u
	jmp [SP_UPDATE,x]
	


_espeed equ 0.8*2;1.125*2
	
EN_V1	equ PR1 * _espeed ;128 ;72 ;48  ;98
EN_V2	equ PR2 * _espeed ;224 ;135 ;90  ;181
EN_V3	equ PR3 * _espeed ;296 ;180 ;120 ;236
EN_V4	equ PR4 * _espeed ;320 ;192 ;128 ;256

EVSX	equ 64/256
EVSY	equ 32/256
	
enemy_vel_table
	fdb -EN_V4 * EVSX,	0
	fdb -EN_V3 * EVSX,	EN_V1 * EVSY
	fdb -EN_V2 * EVSX,	EN_V2 * EVSY
	fdb -EN_V1 * EVSX,	EN_V3 * EVSY
	fdb 0,				EN_V4 * EVSY
	fdb EN_V1 * EVSX,	EN_V3 * EVSY
	fdb EN_V2 * EVSX,	EN_V2 * EVSY
	fdb EN_V3 * EVSX,	EN_V1 * EVSY
	fdb EN_V4 * EVSX,	0
	fdb EN_V3 * EVSX,	-EN_V1 * EVSY
	fdb EN_V2 * EVSX,	-EN_V2 * EVSY
	fdb EN_V1 * EVSX,	-EN_V3 * EVSY
	fdb 0,				-EN_V4 * EVSY
	fdb -EN_V1 * EVSX,	-EN_V3 * EVSY
	fdb -EN_V2 * EVSX,	-EN_V2 * EVSY
	fdb -EN_V3 * EVSX,	-EN_V1 * EVSY
	

	include "coords.asm"
