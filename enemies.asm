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

	ldd #sp_form_enemy
	std SP_DESC,u
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
	
;-----------------------------------------------------------

; velocity scale factors
VSX	equ 64/256
VSY	equ 32/256

; macro to create a velocity table for 16 directions (22.5 degree steps)
; parameter defines speed in pixels per frame.
; first entry is west, subsequent entries counterclockwise.
; (rotated 180 degrees compared to player directions)
mac_velocity_table	macro

1	equ 98 * \1
2	equ 181 * \1
3	equ 236 * \1
4	equ 256 * \1

	fdb -4b*VSX,  0
	fdb -3b*VSX,  1b*VSY
	fdb -2b*VSX,  2b*VSY
	fdb -1b*VSX,  3b*VSY
	fdb  0,       4b*VSY
	fdb  1b*VSX,  3b*VSY
	fdb  2b*VSX,  2b*VSY
	fdb  3b*VSX,  1b*VSY
	fdb  4b*VSX,  0
	fdb  3b*VSX, -1b*VSY
	fdb  2b*VSX, -2b*VSY
	fdb  1b*VSX, -3b*VSY
	fdb  0,      -4b*VSY
	fdb -1b*VSX, -3b*VSY
	fdb -2b*VSX, -2b*VSY
	fdb -3b*VSX, -1b*VSY
	endm



; standard enemy velocity table
std_enemy_vel_table
	mac_velocity_table 0.8

; formation enemy velocity table
form_enemy_vel_table
	mac_velocity_table 1.1



	include "coords.asm"
