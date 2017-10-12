;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	section "_STRUCT"
	org 0

				rmb 8	; sprite coords & velocity

SPM_VALID		rmb 1	; sprite valid if non-zero
SPM_ROUTINE		rmb 2	; pointer to update routine
SPM_DIR			rmb 1	; direction
SPM_TARGET		rmb 2	; pointer to target sprite
SPM_TARGET_OFF	rmb 2	; target marker offset
SPM_SIZE		equ *	; size of data structure


	section "SPRITE_DATA"

; mask + image requires 48 bytes (3x8 sprite)
sp_pmissile_img		rmb 48*4*9

sp_data_pm1		rmb SPM_SIZE
sp_data_pm2		rmb SPM_SIZE


	section "DPVARS"

missile_offset_x	rmb 2	; offsets missile target coords
missile_offset_y	rmb 2	; (e.g. to place target in centre of boss)


	section "CODE"

pmiss_vel_table
	mac_velocity_table 2.5

sp_init_3x8
	jsr sp_unpack_3x8
	clr sp_data_pm1 + SPM_VALID
	clr sp_data_pm2 + SPM_VALID
;pmiss_init
	ldd #pmr_init_target
	std sp_data_pm1 + SPM_ROUTINE
	std sp_data_pm2 + SPM_ROUTINE
	rts


sp_test_3x8_launch
	ldy #sp_data_pm1
	lda SPM_VALID,y
	beq 1f
	ldy #sp_data_pm2
	lda SPM_VALID,y
	bne 9f

1	inca
	sta SPM_VALID,y

	ldd #(PLYR_CTR_X-4)*64
	std SP_XORD,y
	ldd #(PLYR_CTR_Y-3)*32
	std SP_YORD,y
	ldb player_dir
	andb #30
	stb SPM_DIR,y

	ldd #pmr_launch
	std SPM_ROUTINE,y

9	rts

; ---------------------------------------------------------

pmiss_update
	ldy #sp_data_pm1
	jsr [SPM_ROUTINE,y]
	ldy #sp_data_pm2
	jmp [SPM_ROUTINE,y]

; ---------------------------------------------------------
; player missile behaviour routines

; initialise targetting
pmr_init_target
	ldd #sp_data
	std SPM_TARGET,y
	ldd #pmr_find_target
	std SPM_ROUTINE,y
	rts

; search for target
pmr_find_target
	ldu SPM_TARGET,y
	lda SP_MISFLG,u
	bmi 2f
	leax SP_SIZE,u
	cmpx #sp_data_end
	blo 1f
	ldx #sp_data
1	stx SPM_TARGET,y
	rts

2	neg SP_MISFLG,u		; now tracking target
	;stu SPM_TARGET,y
	ldd #pmr_targeting
	std SPM_ROUTINE,y
	ldd #-12*32
	std SPM_TARGET_OFF,y
	rts


; draw target box closing in
pmr_targeting
	ldu SPM_TARGET,y
	lda SP_MISFLG,u
	beq 1f
	jsr pmiss_draw_target_locking
	ldd SPM_TARGET_OFF,y
	addd #32
	bpl 2f
	std SPM_TARGET_OFF,y
	rts

1	ldd #pmr_find_target
	std SPM_ROUTINE,y
	rts

2	ldd #pmr_locked
	std SPM_ROUTINE,y
	rts

pmr_locked
	ldu SPM_TARGET,y
	lda SP_MISFLG,u
	beq 1b
	jmp pmiss_draw_target_locked


; launch
pmr_launch
	ldd #pmr_flight
	std SPM_ROUTINE,y
	rts


; home in on target or random flight
pmr_flight_rnd
	lda SPM_VALID,y
	beq 5f
	ldb [rnd_ptr]
	eorb SP_XORD,y
	andb #4
	subb #2
	addb SPM_DIR,y
	andb #30
	stb SPM_DIR,y
	bra _pmiss_update_sprite


pmr_flight
	lda SPM_VALID,y
	bne 1f
5	ldd #pmr_find_target
	std SPM_ROUTINE,y
	rts

1	ldu SPM_TARGET,y
	lda SP_MISFLG,u
	bne 1f
2	ldd #pmr_flight_rnd
	std SPM_ROUTINE,y
	bra pmr_flight_rnd

1	jsr pmiss_check_hit
	bne 1f
	ldd #pmr_find_target
	std SPM_ROUTINE,y
	inc SP_COLFLG,u		; set collision flag
	ldx SP_DESC,u
	jmp [SP_MISCODE,x]
	;rts

1	jsr pmiss_track
	jsr pmiss_draw_target_locked
;	bra _pmiss_update_sprite


_pmiss_update_sprite

	ldb SPM_DIR,y
	andb #30

	ldx #pmiss_vel_table
	abx
	abx
	ldu ,x
	stu SP_XVEL,y
	ldu 2,x
	stu SP_YVEL,y

	ldx #sp_update_3x8
	cmpb #16
	bls 1f
	ldx #sp_update_3x8_flip
	negb
	addb #32
1	lda #96
	mul
	addd #sp_pmissile_img
	tfr d,u

	jmp ,x


;**********************************************************

; check for hit with target pointed to by u
pmiss_check_hit
	ldd SP_XORD,y
	subd SP_XORD,u
	subd missile_offset_x
	cmpd #-4*64
	blt 1f
	cmpd #8*64
	bgt 1f
	ldd SP_YORD,y
	subd SP_YORD,u
	subd missile_offset_y
	cmpd #-4*32
	blt 1f
	cmpd #8*32
	bgt 1f
	clr SPM_VALID,y
1	rts

; steer missile toward target pointed to by u
pmiss_track
	ldd SP_XORD,u
	addd missile_offset_x
	addd #2				; adjust for difference in sprite size
	subd SP_XORD,y
	lslb
	rola
	sta dx
	ldd SP_YORD,y
	subd SP_YORD,u
	subd missile_offset_y
	subd #2				; adjust for difference in sprite size
	lslb
	rola
	lslb
	rola
	sta dy

	ldb #2		; determine octant
    lda dy		;
	bpl 1f		; y >= 0
	neg dx		; rotate 180 cw
	neg dy		;
	addb #4*4	;
1	lda dx		;
	bpl 1f		; x >= 0
	nega		; rotate 90 cw
	ldx dy   	; don't care about low byte
	stx dx    	;  just need to swap dx & dy
	sta dy		;
	lda dx		;
	addb #2*4	;
1	cmpa dy		;
	bhs 1f		; x >= y
	addb #1*4	;
1
	; determine which direction to rotate
	lda #2
	subb SPM_DIR,y
	beq 5f
	bpl 1f
	nega
	negb
1	cmpb #16
	blo 3f
	nega

3	adda SPM_DIR,y
	anda #30
	sta SPM_DIR,y

5	rts


; draw target markers closing in
; y - missile
; u - target sprite
pmiss_draw_target_locking
	ldd SPM_TARGET_OFF,y
	bsr 1f
	ldu SPM_TARGET,y	; restore u
	ldd #11*32
	subd SPM_TARGET_OFF,y
	bra 1f

; draw target markers locked
; y - missile
; u - target sprite
pmiss_draw_target_locked
	ldd #0
	bsr 1f
	ldu SPM_TARGET,y	; restore u
	ldd #11*32

1	addd SP_YORD,u
	addd missile_offset_y
	cmpd #SCRN_HGT*32
	bhs 9f			; off top or bottom of screen
	andb #$e0		; remove sub-pixel bits
	adda td_fbuf	; screen base
	tfr d,x
	ldd SP_XORD,u
	addd missile_offset_x
	cmpa #28
	bhi 9f			; off left or right of screen

	leax a,x
	lsrb
	lsrb
	lsrb
	andb #24
	ldu #pmiss_target_table
	leau b,u
	ldd ,u
	anda ,x
	andb 1,x
	addd 4,u
	std ,x
 	ldd 2,u
	anda 2,x
	andb 3,x
	addd 6,u
	std 2,x

9	rts

pmiss_target_table
	fdb $0000,$00ff
	fdb $5555,$5500
	fdb $c000,$003f
	fdb $1555,$5540
	fdb $f000,$000f
	fdb $0555,$5550
	fdb $fc00,$0003
	fdb $0155,$5554


;**********************************************************
