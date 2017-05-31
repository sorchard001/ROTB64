;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	; cyd needs to be page aligned
	align 256

	include "cyd.s"

;------------------------------------------------

	section "CYD_WAVES"

	org CFG_CYD_WAVES_ADDR

reserve_wave macro
\1	equ *+128
	rmb 256
	endm

	reserve_wave "silent"
	reserve_wave "sqr2"
	reserve_wave "sqr1"
	reserve_wave "sqr0"
	reserve_wave "nzz2"
	reserve_wave "nzz1"
	reserve_wave "nzz0"
	reserve_wave "saw2"
	reserve_wave "saw1"
	reserve_wave "saw0"
	reserve_wave "tri2"
	reserve_wave "tri1"
	reserve_wave "tri0"

;------------------------------------------------

	section "CODE"

; generate waveforms for CyD player
init_cyd_waves
	ldu #cyd_wave_params

	; silent and square waves generated with block fill
	ldx #silent-128
1	ldd ,u++
	beq 2f
	bsr block_fill
	bra 1b
2
	; noise waves generated with prng
1	ldd ,u++
	beq 3f
	bsr rnd_fill
	bra 1b
3
	; saw & triangle waves generated with ramp fill
1	bsr ramp_fill
	lda ,u
	bne 1b

	rts


; block fill
; start address in X, value in A, count in B
block_fill
1	sta ,x+
	decb
	bne 1b
	rts

; fill region with pseudo-random values
; start address in X, scale factor in A, offset in B
rnd_fill
	sta 2f+1	; amplitude
	stb 3f+1	; offset
	ldy #256
1
wrndx lda #0		; xabc pseudo-random number generator
	inca			; converted from c source found on www.eternityforest.com
	sta wrndx+1
wrnda eora #0
wrndc eora #0
	sta wrnda+1
wrndb adda #0
	sta wrndb+1
	lsra
	adda wrndc+1
	eora wrnda+1
	sta wrndc+1

2	ldb #0
	mul
3	adda #0
	sta ,x+
	leay -1,y
	bne 1b
	rts


; fill region with increasing or decreasing value (1st or 8th octant only)
; start address in X, param address in U
ramp_fill
	ldd 1,u		; a=dx, b=y0
	inca
	sta temp0	; loop count = dx+1
	deca
	lsra
	nega		; initial error term

1	stb ,x+
	adda ,u		; dy
	bcc 2f
	suba 1,u	; dx
	addb 3,u	; +/-1
2	dec temp0
	bne 1b

	leau 4,u	; point to next param set

	rts


wave2_min	equ $01
wave2_max	equ $54
wave1_min	equ $0e
wave1_max	equ $46
wave0_min	equ $1e
wave0_max	equ $38

wave_quiescent	equ $2a

cyd_wave_params

	; block fill parameter table: value, count
	; (count=0 loops 256 times)

	fcb wave_quiescent, 0				; silent
	fcb wave2_max, 128, wave2_min, 128	; sqr2
	fcb wave1_max, 128, wave1_min, 128	; sqr1
	fcb wave0_max, 128, wave0_min, 128	; sqr0
	fdb 0

	; noise parameter table:  scale factor, offset

	fcb wave2_max - wave2_min, wave2_min	; nzz2
	fcb wave1_max - wave1_min, wave1_min	; nzz1
	fcb wave0_max - wave0_min, wave0_min	; nzz0
	fdb 0

	; ramp parameter table: |dy|, dx, y0, inc/dec
	; (run length = dx + 1)

	fcb wave2_max - wave2_min, 255, wave2_min, 1	; saw2
	fcb wave1_max - wave1_min, 255, wave1_min, 1	; saw1
	fcb wave0_max - wave0_min, 255, wave0_min, 1	; saw0

	fcb wave2_max - wave2_min, 127, wave2_min, 1	; tri2
	fcb wave2_max - wave2_min, 127, wave2_max, -1
	fcb wave1_max - wave1_min, 127, wave1_min, 1	; tri1
	fcb wave1_max - wave1_min, 127, wave1_max, -1
	fcb wave0_max - wave0_min, 127, wave0_min, 1	; tri0
	fcb wave0_max - wave0_min, 127, wave0_max, -1

	fcb 0


;------------------------------------------------

	include "tune_macros.asm"


envelope_0
	fcb	silent>>8,0

envelope_1
	fcb saw2>>8,0
envelope_2
	fcb saw1>>8,0
envelope_3
	fcb saw0>>8,0

envelope_4
	fcb sqr2>>8,0
envelope_5
	fcb sqr1>>8,0



;kick
envelope_10
	fcb sqr2>>8,tri2>>8,tri2>>8,tri2>>8,tri2>>8,tri2>>8,tri2>>8,tri1>>8,0

;snare
envelope_11
	fcb nzz2>>8,nzz2>>8,nzz1>>8,nzz1>>8,nzz1>>8,0
envelope_12
	fcb nzz0>>8,0
envelope_13
	fcb nzz1>>8,0



patch_table

patch_0
	fcb	0
	fdb	envelope_0,envelope_0
patch_1
	fcb	5
	fdb	envelope_1,envelope_2
patch_2
	fcb	5
	fdb	envelope_2,envelope_3
patch_3
	fcb	8
	fdb	envelope_4,envelope_5

;kick
patch_4
	fcb 9
	fdb envelope_10,envelope_0

;snare
patch_5
	fcb 5
	fdb envelope_11,envelope_12
;snare_flam
patch_6
	fcb 2
	fdb envelope_13,envelope_12

;lead
patch_7
	fcb 8
	fdb envelope_1,envelope_3


; basic note length
n1	equ 7


tune0_c1
	; fixme: cyd select_tune should initialise these
	_setport 0
	_settp 0
	_setarp 0,arp0
1
	;fcb silence,n1*16
	;_jump 1b

	_loop 3
	_call bass_main
	_call bass_main
	_call bass_main
	_call bass_main
	_next

	_loop 2
	_settp -2
	_call bass_main
	_call bass_main
	_settp 0
	_call bass_main
	_call bass_main
	_next

	_jump 1b


bass_main
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e2,n1
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e2,n1
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e1,n1
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e2,n1
	_setpatch 1
	fcb e1,n1
	_setpatch 1
	fcb e2,n1
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e2,n1
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e2,n1
	_setpatch 2
	fcb e2,n1
	_setpatch 1
	fcb e2,n1

	_return


;arp1	fcb	3,7,0
;arp2	fcb	4,7,0
arp3	fcb	7,12,0
arp4	fcb	7,0
arp5	fcb	12,12,12,12,0
arp0	equ *-1


tune0_c2
	_setport 0
	_settp 0
	_setarp 0,arp0
1

 if 1
	_setpatch 3
	_call intro_bass
	_call intro_bass
	_call intro_bass
	_setport -5
	_calltp 12,intro_bass
	_settp 0
 endif

	_setpatch 7
	_setport 0
	_call intro_lead1
	_call intro_lead2
	_call intro_lead1
	_call intro_lead3

	_setarp 3,arp4
	_call intro_lead1
	_call intro_lead2
	_call intro_lead1
	_call intro_bass
	_setarp 0,arp0

	_loop 2
	_setpatch 1
	;_setport -1
	_call lead4
	_call lead5
	_setpatch 7
	;_setport 0
	_call intro_lead1
	_call intro_bass
	_next

	_jump 1b


intro_bass
	fcb e1,n1
	fcb silence,n1*9
	fcb e1,n1*6
	_return

;lead_vib equ 2


intro_lead1
	fcb e3,n1*8
	fcb g4,n1*3
	fcb d4,n1*3
	fcb e4,n1*2
	_return

intro_lead2
	fcb rest,n1*6
	fcb d4,n1*3
	fcb d4,n1*3
	fcb g4,n1*4
	_return

intro_lead3
	fcb rest,n1*9
	fcb e4,n1*1
	fcb e4,n1*2
	fcb f4,n1*2
	fcb g4,n1*2
	_return

lead4
	fcb d3,n1*2
	fcb d3,n1
	fcb f3,n1
	fcb d3,n1
	fcb d3,n1
	fcb g3,n1
	fcb d3,n1
	fcb d3,n1
	fcb f3,n1
	fcb d3,n1
	fcb d3,n1
	fcb d3,n1
	fcb d3,n1
	fcb f3,n1*2
	_return

lead5
	fcb d3,n1*2
	fcb d3,n1
	fcb f3,n1
	fcb d3,n1
	fcb d3,n1
	fcb g3,n1
	fcb d3,n1
	fcb d3,n1
	fcb f3,n1
	fcb d3,n1
	fcb d3,n1
	fcb f3,n1
	fcb d3,n1
	fcb f3,n1*2
	_return

kick_freq	equ e2	;f2;e2
kick_port equ -2 	;-40;-2
snare_freq equ 138	;b0;134
snare_port equ -3	;-10;-2

tune0_c3
	_setport 0
	_settp 0
	_setarp 0,arp0
1
	_call drum1
	_call drum1
	_call drum1
	_call drum4

	_call drum1
	_call drum1
	_call drum1
	_call drum2

	_loop 3
	_call drum1
	_call drum2
	_call drum1
	_call drum3
	_next

	_jump 1b



drum1
	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1
	fcb kick_freq,n1*2
	fcb kick_freq,n1

	_setpatch 5
	_setport snare_port
	fcb snare_freq,n1*2

	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1
	fcb kick_freq,n1*2
	fcb kick_freq,n1
	fcb kick_freq,n1
	fcb kick_freq,n1

	_setpatch 5
	_setport snare_port
	fcb snare_freq,n1*2
	fcb snare_freq,n1*2

	_return


drum2
	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1
	fcb kick_freq,n1*2
	fcb kick_freq,n1

	_setpatch 5
	_setport snare_port
	fcb snare_freq,n1*2

	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1
	fcb kick_freq,n1*2
	fcb kick_freq,n1
	fcb kick_freq,n1
	fcb kick_freq,n1

	_setpatch 5
	_setport snare_port
	fcb snare_freq,n1*2
	fcb snare_freq,n1
	fcb snare_freq,n1

	_return

drum3
	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1
	fcb kick_freq,n1*2
	fcb kick_freq,n1

	_setpatch 5
	_setport snare_port
	fcb snare_freq,n1*2

	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1
	fcb kick_freq,n1*2

	_setpatch 5
	_setport snare_port
	fcb snare_freq,n1
	fcb snare_freq,n1*2-4

	_setpatch 6
	fcb snare_freq,4

	_setpatch 5
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1
	_setport 0

	_return


drum4
	_setpatch 4
	_setport kick_port
	fcb kick_freq,n1

	_setpatch 6
	_setport snare_port
	fcb snare_freq,4
	fcb snare_freq,n1-4
	_setpatch 5
	fcb snare_freq,n1*2
	fcb snare_freq,n1
	fcb snare_freq,n1*2-4
	_setpatch 6
	fcb snare_freq,4
	_setpatch 5
	fcb snare_freq,n1*2
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1
	fcb snare_freq,n1

	_return

