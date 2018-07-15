;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "DPVARS"

en_std_max	rmb 1	; max number of standard enemies
en_spawn_count	rmb 1	; counts number of standard enemies spawned vs formations
en_form_count	rmb 1	; counts number of enemies remaining to be in formation
en_count	rmb 1	; counts number of enemies destroyed
en_spawn_param	rmb 2	; parameter for sprite initialisation


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


en_spawn
	lda en_spawn_count	; time to spawn formation yet?
	bne 1f			; spawn standard enemy

; spawn enemy formation
	lda sp_count		; enough free sprites to spawn formation?
	cmpa #CFG_NUM_SPRITES-4	;
	bhi 9f			; not enough - rts

	lda #EN_FORM_PERIOD
	sta en_spawn_count
	lda #4
	sta en_form_count
	lda #-8
	sta en_spawn_param

	ldx #sp_form_update_init
	bsr en_new_sprite 
	bsr en_new_sprite 
	bsr en_new_sprite 
	bsr en_new_sprite 

	ldx #SND_ALERT
	jmp snd_start_fx

; spawn two standard enemies
1	lda en_std_max
	suba #2
	cmpa sp_count
	blo 9f
	lda #-8
	sta en_spawn_param
	dec en_spawn_count
	ldx #sp_std_enemy_update_init
	bsr en_new_sprite 

; allocate collidable sprite from free list
; pointer to update routine in x
; returns new sprite in u
; assumes free sprite is available
en_new_sprite
	ldu sp_free_list	; get next free sprite
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_pcol_list	; add sprite to collidable list
	std SP_LINK,u		;
	stu sp_pcol_list	;
	inc sp_count		; increase allocated count
	stx SP_UPDATEP,u	; pointer to update routine
9	rts


;-----------------------------------------------------------


	include "coords.asm"

