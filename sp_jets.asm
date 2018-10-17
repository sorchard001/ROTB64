;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

; jet formation

	section "CODE"

sp_jet_grfx
	include "grfx/sp_jet.asm"


sp_jet_desc
1	fdb sp_jet_offscreen	; offscreen handler
	fdb SND_EXPL_S		; explosion sound
	fcb $10			; score 100
	fdb 0			; on bullet hit n/a
	fdb sp_jet_mhit		; missile hit
	assert (*-1b) == SP_DESC_SIZE, "sp_jet_desc wrong_size"

sp_jet_ps_params
	fcb 3			; number of sprites to preshift
	fdb sp_jet_grfx_ps	; destination
	fdb sp_jet_grfx		; source

sp_jet_spawn
	lda #5
	sta sp_ref_count
	sta en_form_count
	lda #-8
	sta en_spawn_param
	ldu #sp_jet_ps_params
	jsr en_update_ps_setup
	ldy #sp_jet_update_0
	jsr en_new_col_sprite 
	jsr en_new_col_sprite 
	jsr en_new_col_sprite 
	jsr en_new_col_sprite 
	jmp en_new_col_sprite 


sp_jet_update_0
	ldd #58*64
	adda en_spawn_param
	std SP_XORD,y
	ldd #(SCRN_HGT*32-1)
	std SP_YORD,y
	ldd #0
	std SP_XVEL,y
	ldb en_spawn_param
	bpl 1f
	negb
1	asrb
	asrb
	sex
	addd #-36
	std SP_YVEL,y
	ldb en_spawn_param
	addb #4
	stb en_spawn_param
	dec SP_MISFLG,y		; missile target
	ldd #sp_jet_grfx_ps
	std SP_FRAMEP,y
	ldd #sp_jet_desc
	std SP_DESC,y
	;ldd #sp_jet_update_1
	ldd #sp_update_sp4x12
	std SP_UPDATEP,y
	jmp sp_update_sp4x12_next


sp_jet_update_1
	jmp sp_update_sp4x12


sp_jet_mhit
	dec sp_ref_count
	dec en_form_count
	lbne sp_std_bhit
	inc sp_ref_count
	ldx #sp_expl_bonus_update_0
	jmp sp_update_explode_custom
	;jmp sp_std_bhit


sp_jet_offscreen
	lda SP_XORD,y
	cmpa #-6
	blt 1f
	cmpa #34
	bge 1f
	ldd SP_YORD,y
	cmpd #(-11*32)
	blt 1f
	cmpd #(SCRN_HGT*32)
	bge 1f
	jmp sp_update_sp4x12_next
1	jmp sp_remove_ref


