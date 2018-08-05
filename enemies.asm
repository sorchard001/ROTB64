;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2018 S. Orchard
;**********************************************************

	section "DPVARS"

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
EN_FORM_PERIOD equ 8

en_init_all
	lda #EN_SPAWN_PERIOD
	sta en_spawn_rate
	lda #EN_FORM_PERIOD
	sta en_spawn_count
	;clr en_count
	;lda #3
	;sta en_std_max
	rts


en_spawn
	lda en_spawn_count	; time to spawn formation yet?
	bne 1f			; spawn standard enemies

; spawn enemy formation
	lda sp_count		; enough free sprites to spawn formation?
	cmpa #CFG_NUM_SPRITES-4	;
	bhi 9f			; not enough - rts
	lda #EN_FORM_PERIOD
	sta en_spawn_count
	lda #4
	sta en_form_count
	jmp sp_form_spawn

; spawn two standard enemies
1	dec en_spawn_rate
	bne 9f			; rts
	lda #EN_SPAWN_PERIOD
	sta en_spawn_rate
	lda en_std_max
	suba #2
	cmpa sp_count
	blo 9f			; rts
	dec en_spawn_count
	jmp sp_std_spawn


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

