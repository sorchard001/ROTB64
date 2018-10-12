;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

; fireballs

	section "CODE"

sp_fball_grfx
	include "grfx/sp_fball.asm"


sp_fball_desc
1	fdb sp_remove		; offscreen handler
	fdb SND_EXPL_S		; explosion sound
	fcb 1			; score 10
	fdb sp_update_explode	; on bullet hit
	fdb 0			; missile hit n/a
	assert (*-1b) == SP_DESC_SIZE, "sp_fball_desc wrong_size"

sp_fball_ps_params
	fcb 2			; number of sprites to preshift
	fdb sp_fball_grfx_ps	; destination
	fdb sp_fball_grfx	; source


sp_fball_spawn
	ldu #sp_fball_ps_params
	jsr en_update_ps_setup
	ldy #sp_fball_update_0	; address of initialiser
	jmp en_new_aux_sprite 


sp_fball_update_0
	ldu boss_sprite

	ldd SP_XORD,u
	addd #-6*64
	std SP_XORD,y
	ldd SP_YORD,u
	addd #-6*32
	std SP_YORD,y
	
	ldd SP_XORD,u		; calculate distance of boss from player
	subd #(PLYR_LEFT*64)
	addd #-6*64		; adjustment to allow for size of boss
	lslb
	rola
	lslb
	rola
	sta dx
	ldd #(PLYR_TOP*32)
	subd SP_YORD,u
	subd #-6*32		; adjustment to allow for size of boss
	lslb
	rola
	lslb
	rola
	lslb
	rola
	sta dy
	jsr sp_calc_octant

	ldx #sp_fball_vel_table
	lsrb
	lsrb
	andb #$3c
	abx
	ldd ,x
	;addd SP_XVEL,u
	subd scroll_x
	std SP_XVEL,y
	ldd 2,x
	;addd SP_YVEL,u
	subd scroll_y
	std SP_YVEL,y
	ldd #sp_fball_desc
	std SP_DESC,y
	ldd #sp_fball_grfx_ps
	std SP_FRAMEP,y
	ldd #sp_fball_update_1
	std SP_UPDATEP,y
	jmp sp_update_sp4x12_next


sp_fball_update_1
	ldd SP_FRAMEP,y
	addd #384
	cmpd #sp_fball_grfx_ps+2*384
	blo 1f
	ldd #sp_fball_grfx_ps
1	std SP_FRAMEP,y
	lda boss_hit
	beq 1f
	ldd #sp_update_explode
	std SP_UPDATEP,y
1	jmp sp_update_sp4x12
	

sp_fball_vel_table
	mac_velocity_table_180 0.5
