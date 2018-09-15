;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

	section "DPVARS"

en_spawn_vec	rmb 2	; pointer to current spawn routine
en_std_max	rmb 1	; max number of standard enemies
en_spawn_rate	rmb 1	; enemy spawn rate counter
en_spawn_count	rmb 1	; counts number of std enemies spawned vs formations
en_form_count	rmb 1	; counts number of enemies remaining in formation
en_count	rmb 1	; counts number of enemies destroyed
en_spawn_param	rmb 2	; parameter for sprite initialisation
en_update_ps_vec	rmb 2	; preshift sequence vector
en_ps_sync_count rmb 1	; sync counter used to get all sprites in group
			; to complete preshift sequence on same video frame


	section "CODE"

; enemy spawn rate
EN_SPAWN_PERIOD equ 6

; formation spawn rate
;EN_FORM_PERIOD equ 8

en_init_all
	lda #EN_SPAWN_PERIOD
	sta en_spawn_rate
	;lda #EN_FORM_PERIOD
	lda #1
	sta en_spawn_count
	ldd #en_svec_std
	std en_spawn_vec
	;clr en_count
	;lda #3
	;sta en_std_max
en_svec_nop
9	rts


en_spawn
	jmp [en_spawn_vec]

; spawn enemies
en_svec_main
	dec en_spawn_rate
	bne 9b
	lda #EN_SPAWN_PERIOD
	sta en_spawn_rate

	inc en_spawn_count
	lda en_spawn_count
	bita #7
	beq 2f		; formation
	bita #3
	beq 1f		; rotating enemy
	ldd #en_svec_std
	bra 5f
1	ldd #en_svec_rot
	bra 5f
2	ldd #en_svec_form
5	std en_spawn_vec
	rts
	

; waiting to spawn standard enemies
en_svec_std
	lda en_std_max		; check number of enemies
	suba #2			; already on screen
	cmpa sp_count		;
	blo 9b			; rts
	ldd #en_svec_main
	std en_spawn_vec
	jmp sp_std_spawn

; waiting to spawn rotating enemies
en_svec_rot
	lda sp_count		; enough free sprites?
	cmpa #CFG_NUM_SPRITES-2	;
	bhi 9b			; not enough - rts
	ldd #en_svec_main
	std en_spawn_vec
	lda sp_ref_count	; preshift buffer free?
	lbne sp_std_spawn	; no - spawn standard enemy instead
	jmp sp_rot_spawn

; waiting to spawn formation
en_svec_form
	lda sp_count		; enough free sprites?
	cmpa #CFG_NUM_SPRITES-4	;
	bhi 9b			; not enough - rts
	ldd #en_svec_main
	std en_spawn_vec
	lda sp_ref_count	; preshift buffer free?
	lbne sp_std_spawn	; no - spawn standard enemy instead
	jmp sp_form_spawn


; initial delay before boss starts firing
en_svec_boss
	lda sp_count
	bne 9f			; rts
	lda #6
	sta en_spawn_rate
	ldd #en_svec_boss_fball_0
	std en_spawn_vec
	jmp sp_boss_spawn

en_svec_boss_fball_0
	dec en_spawn_rate
	bne 9f
	ldd #en_svec_boss_fball_1
	std en_spawn_vec
	rts

en_svec_boss_fball_1
	ldy sp_free_list
	beq 9f			; rts
	ldd #en_svec_boss_fball_0
	std en_spawn_vec
	lda #2
	sta en_spawn_rate
	jmp sp_fball_spawn

en_svec_warp
	lda sp_count
	bne 9f			; rts
	ldd #en_svec_nop
	std en_spawn_vec
	jmp sp_warp


; allocate collidable sprite from free list
; pointer to update routine in x
; optional data in y
; returns new sprite in u
; assumes free sprite is available

en_new_col_sprite
	ldu sp_free_list	; get next free sprite
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_pcol_list	; add sprite to collidable list
	std SP_LINK,u		;
	stu sp_pcol_list	;
	inc sp_count		; increase allocated count
	stx SP_UPDATEP,u	; pointer to update routine
	sty SP_DATA,u		; optional data
9	rts


; allocate aux sprite from free list
; pointer to update routine in x
; optional data in y
; returns new sprite in u
; assumes free sprite is available

en_new_aux_sprite
	ldu sp_free_list	; get next free sprite
	ldd SP_LINK,u		; remove sprite from free list
	std sp_free_list	;
	ldd sp_aux_list		; add sprite to aux list
	std SP_LINK,u		;
	stu sp_aux_list		;
	inc sp_count		; increase allocated count
	stx SP_UPDATEP,u	; pointer to update routine
	sty SP_DATA,u		; optional data
9	rts


;-----------------------------------------------------------
; Sprite preshift sequencing
; Each unit of work should be 1000 cycles or fewer
; (i.e. to take no more time than an active sprite)
; Only one set of sprite graphics can be processed at a time
; Multiple sprites can call the routines to get the work done faster

; Initialise preshift sequence
; Called from code that allocates sprites
; D contains address of preshift params
; returns address of updater in X
en_update_ps_setup
	std sp4x12_ps_params	; preshift params
	ldd #en_ps_vec0		; setup first routine in sequence
	std en_update_ps_vec	;
	ldx #en_update_ps	; return address of preshift updater
	rts

; Called via sprite UPDATEP to perform next step in sequence
en_update_ps
	jsr [en_update_ps_vec]
	jmp sp_update_sp4x12_next

; Preshift routines called via en_update_ps_vec

; Copy first unshifted sprite frame
; (Expanding from 3 to 4 byte wide format)
en_ps_vec0
	ldx sp4x12_ps_params	; get sync count
	lda 5,x			;
	sta en_ps_sync_count	;
	ldd #en_ps_vec1
	std en_update_ps_vec
	jmp sp4x12_ps_first

; Generate remaining shifted frames
; 6 calls required to process the 3 frames
en_ps_vec1
	jsr sp4x12_ps_next
	bne 9f
	ldd #en_ps_vec2
	std en_update_ps_vec
	dec en_ps_sync_count	; sync count is used to ensure all sprites
	bpl 9f			; in group exit preshift in same video frame
	ldd SP_DATA,y
	std SP_UPDATEP,y
9	rts

; Final routine sets up sprite initialiser and jumps to it
en_ps_vec2
	dec en_ps_sync_count
	bpl 9b
	ldx SP_DATA,y
	stx SP_UPDATEP,y
	leas 2,s
	jmp ,x

;-----------------------------------------------------------


	include "coords.asm"

