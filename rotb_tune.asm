;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

	align 256

include_wave macro
\1	equ *+128
	includebin "waves/&1.bin"
	endm

	include_wave "saw2"
	include_wave "saw1"
	include_wave "saw0"

	include_wave "tri2"
	include_wave "tri1"
	include_wave "tri0"

	include_wave "nzz2"
	include_wave "nzz1"
	include_wave "nzz0"

	; cyd needs to be page aligned
	include "cyd.s"

;------------------------------------------------

	section "CYD_WAVES"
	
	org CFG_CYD_WAVES_ADDR

silent	equ *+128
		rmb 256

sqr2	equ *+128
		rmb 256
sqr1	equ *+128
		rmb 256
sqr0	equ *+128
		rmb 256

;------------------------------------------------

	section "CODE"

init_cyd_waves
	ldu #cyd_wave_params
1	ldx ,u++
	beq 2f
	ldd ,u++
	bsr block_fill
	bra 1b
	
2	rts


block_fill
1	sta ,x+
	decb
	bne 1b
	rts


cyd_wave_params
	fdb silent-128, $2a00
	fdb sqr2-128, $5480
	fdb sqr2, $0180
	fdb sqr1-128, $4680
	fdb sqr1, $0e80
	fdb sqr0-128, $3880
	fdb sqr0, $1c80
	fdb 0
	
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

