;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

; rotating enemy

	section "CODE"

sp_rot_grfx
	include "grfx/sp_rot.asm"


sp_rot_desc
1	fdb sp_remove_ref	; offscreen handler
	fdb SND_EXPL_S		; explosion sound
	fcb 5			; score 50
	fdb 0			; on bullet hit n/a
	fdb sp_rot_bhit		; missile hit
	assert (*-1b) == SP_DESC_SIZE, "sp_rot_desc wrong_size"

sp_rot_ps_params
	fcb 3			; number of sprites to preshift
	fdb sp_rot_grfx_ps	; destination
	fdb sp_rot_grfx		; source
	fcb 0			; frame sync count

sp_rot_spawn
	inc sp_ref_count
	inc sp_ref_count
	lda #-8
	sta en_spawn_param
	ldd #sp_rot_ps_params
	jsr en_update_ps_setup
	ldy #sp_rot_update_0
	jsr en_new_col_sprite 
	jmp en_new_col_sprite 


sp_rot_update_0
	ldb player_dir
	stb SP_DATA,y		; direction
	stb SP_DATA2,y
	lsrb
	andb #$78
	ldx #form_coords
	abx
	lsrb
	ldu #sp_rot_vel_table
	leau b,u
	ldb en_spawn_param
	leax b,x
	addb #16
	stb en_spawn_param
	ldd ,x
	std SP_XORD,y
	ldd 2,x
	std SP_YORD,y
	ldd ,u
	std SP_XVEL,y
	ldd 2,u
	std SP_YVEL,y
	dec SP_MISFLG,y		; missile target
	lda en_spawn_param
	anda #16
	lsra
	adda #20
	sta SP_DATA3,y
	ldd #sp_rot_grfx_ps
	std SP_FRAMEP,y
	ldd #sp_rot_desc
	std SP_DESC,y
	ldd #sp_rot_update_1
	std SP_UPDATEP,y
	jmp sp_update_sp4x12_next


sp_rot_update_1
	ldd SP_FRAMEP,y
	addd #384
	cmpd #sp_rot_grfx_ps+3*384
	blo 1f
	ldd #sp_rot_grfx_ps
1	std SP_FRAMEP,y

	ldb SP_DATA,y
	cmpb SP_DATA2,y
	beq 1f
	bmi 2f
	addb #8
	bra 3f
2	subb #8
3	stb SP_DATA,y
	;bra 5f

1	dec SP_DATA3,y
	bne 5f
	lda #20
	sta SP_DATA3,y
	ldb [rnd_ptr]
	andb #$f0
	stb SP_DATA2,y	
	ldb SP_DATA,y

5	andb #$f0
	lsrb
	lsrb
	ldu #sp_rot_vel_table
	leau b,u
	ldd ,u
	std SP_XVEL,y
	ldd 2,u
	std SP_YVEL,y

	jmp sp_update_sp4x12


sp_rot_bhit
	dec sp_ref_count
	jmp sp_std_bhit


sp_rot_vel_table
	mac_velocity_table_180 1.25

