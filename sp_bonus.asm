;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

; sprite displaying bonus score

	section "CODE"

sp_bonus_grfx
	include "grfx/sp_1000.asm"

sp_expl_bonus_desc
1	fdb sp_remove_ref	; offscreen handler
	fdb 0			; explosion sound n/a
	fcb 0			; score n/a
	fdb 0			; on bullet hit n/a
	fdb 0			; on missile hit n/a
	assert (*-1b) == SP_DESC_SIZE, "sp_expl_bonus_desc wrong size"


sp_bonus_desc
1	fdb sp_remove_ref	; offscreen handler
	fdb 0			; explosion sound n/a
	fcb 0			; score n/a
	fdb 0			; on bullet hit n/a
	fdb 0			; missile hit n/a
	assert (*-1b) == SP_DESC_SIZE, "sp_bonus_desc wrong_size"

sp_bonus_ps_params
	fcb 3			; number of sprites to preshift
	fdb sp_bonus_grfx_ps	; destination
	fdb sp_bonus_grfx	; source

sp_bonus_spawn
	inc sp_ref_count
	ldu #sp_bonus_ps_params
	jsr en_update_ps_setup
	ldy #sp_bonus_update_0
	jmp en_new_col_sprite 


sp_expl_bonus_update_0
	ldu #sp_bonus_ps_params
	jsr sp4x12_ps_setup
	ldu #sp_expl_frames
	stu SP_DATA,y
	ldd #sp_expl_bonus_desc
	std SP_DESC,y
	ldd #sp_expl_bonus_update_1
	std SP_UPDATEP,y
	;jmp sp_update_sp4x12_next
	bra 1f

sp_expl_bonus_update_1
	ldu SP_DATA,y
1	ldd ,u++
	beq 2f
	stu SP_DATA,y
	std SP_FRAMEP,y
	jmp sp_update_sp4x12
2
	ldx #en_update_ps
	stx SP_UPDATEP,y
	ldd #sp_bonus_update_0
	std SP_DATA,y
	jmp ,x


sp_bonus_update_0
	clra
	clrb
	std SP_XVEL,y
	ldd #-8
	std SP_YVEL,y
	lda #100
	sta SP_DATA,y
	ldd #sp_bonus_grfx_ps
	std SP_FRAMEP,y
	ldd #sp_bonus_desc
	std SP_DESC,y
	ldd #sp_bonus_update_1
	std SP_UPDATEP,y
	lda #1			; score 1000
	jsr bonus_score		;
	inc kill_count
	lda kill_count
	anda #3
	lsla
	ldx #SND_FX_TAB
	ldx a,x
	jsr snd_start_fx
	jmp sp_update_sp4x12_next

SND_FX_TAB	fdb SND_TONE2,SND_TONE3,SND_TONE4,SND_TONE5


sp_bonus_update_1
	dec SP_DATA,y
	lbeq sp_remove_ref
	ldd SP_FRAMEP,y
	addd #384
	cmpd #sp_bonus_grfx_ps+3*384
	blo 1f
	ldd #sp_bonus_grfx_ps
1	std SP_FRAMEP,y
	jmp sp_update_sp4x12

