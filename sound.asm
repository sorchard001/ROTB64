;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************


	section "DPVARS"

snd_buf_ptr		rmb 2
snd_count		rmb 1
snd_vol			rmb 1
snd_freq		rmb 1
snd_phase		rmb 1
snd_fx			rmb 2


	section "DATA"

; soundbuf should avoid crossing page boundary to allow 8 bit increment
soundbuf		rmb 48
soundbuf_end	equ *

	; check buffer fits inside one page
	assert	((soundbuf_end-1) & $ff00) == (soundbuf & $ff00), "soundbuf crosses page"

	

	section "RUN_ONCE"

; called once on program initialisation
snd_init
	;lda $ff23
	;ora #8
	;sta $ff23
	clra
	clrb
	sta snd_count
	std snd_fx
	jmp snd_clear_buf

	
	section "CODE"

; start a sound effect if it has priority	
snd_start_fx
	cmpx snd_fx
	blo 9f
	
; force a sound effect to start
snd_start_fx_force
	stx snd_fx
	ldd ,x				; a=duration, b=vol
	sta snd_count
	stb snd_vol
	lda _SND_FREQ,x		; frequency
	sta snd_freq
9	rts
	
	
; call once per game loop to fill sound buffer and process sound effects
snd_update
	ldx #soundbuf
	stx snd_buf_ptr
	ldy snd_fx
	beq nosound
	dec snd_count
	beq 8f
	jmp [_SND_FXJMP,y]

8	lda _SND_NEXT,y
	beq 9f
	leax 8,y
	bra snd_start_fx_force
9	clra
	clrb
	std snd_fx
	rts
	;ldx #SND_BACKG
	;bra snd_start_fx_force
	
snd_clear_buf
	ldx #soundbuf
	stx snd_buf_ptr
nosound
	clra
	clrb
1	std ,x++
	cmpx #soundbuf_end
	blo 1b
donesound
	stb snd_phase		; save phase acc for next time
	ldd snd_vol			; snd_vol & snd_freq
	adda _SND_DVOL,y	; change volume
	addb _SND_DFREQ,y	; change freq
	std snd_vol			; snd_vol & snd_freq
	rts
	
; noise generator	
snd_noise
	ldu #rndtable
	ldd snd_vol		; snd_vol & snd_freq
	sta 2f+1		; volume
	stb 3f+1		; frequency
	ldb snd_phase
	anda ,u+		; first sample
4	sta ,x+
3	addb #0			; frequency
	bcc 1f
	lda ,u+
2	anda #0			; volume
1	cmpx #soundbuf_end
	blo 4b
	bra donesound


; square wave tone gen is faster than noise and can be left unoptimised
; commented out code continues with previous volume level
snd_square
	ldb snd_phase
	lda snd_vol
;5	anda #$ff
2	sta ,x+
	addb snd_freq
	bcc 1f
	eora snd_vol
1	cmpx #soundbuf_end
	blo 2b
;	tsta
;	beq 1f
;	lda #$ff
;1	sta 5b+1
	bra donesound

	
; sound effects parameter table
; higher address gives sound higher priority

	section "_STRUCT"
	org 0

; structure of table entries
_SND_DURATION	rmb 1	; duration in game loops
_SND_VOL		rmb 1	; start volume
_SND_DVOL		rmb 1	; change in volume per game loop
_SND_FREQ		rmb 1	; start frequency
_SND_DFREQ		rmb 1	; change in frequency per game loop
_SND_FXJMP 		rmb 2	; address of tone generator
_SND_NEXT		rmb 1	; flag to run next entry at end


	section "CODE"

;SND_BACKG	fcb 25,37,0,255,-6
;			fdb snd_square
;			fcb 1
;			fcb 25,37,0,105,6
;			fdb snd_square
;			fcb 0

;SND_WARPIN	fcb 40,192,-1,200,-4
SND_WARPIN	fcb 40,192,-1,240,-5
			fdb snd_square
			fcb 0
			
SND_FIRE	fcb 8,64,-5,192,-16
			fdb snd_noise
			fcb 0

SND_START	fcb 64,128,-2,255,-32
			fdb snd_square
			fcb 0

SND_EXPL_S	fcb 15,255,-17,255,-17
			fdb snd_noise
			fcb 0
			
SND_EXPL_F	fcb 12,255,-21,144,-12
			fdb snd_square
			fcb 0

SND_TONE2	fcb 16,192,-11,255,-129
			fdb snd_square
			fcb 0
	
SND_TONE3	fcb 16,192,-11,255,-2
			fdb snd_square
			fcb 0

SND_TONE4	fcb 8,192,0,128,15
			fdb snd_square
			fcb 0

SND_TONE5	fcb 16,192,0,64,6
			fdb snd_square
			fcb 0
			
SND_ALERT	fcb 6,192,0,64,32
			fdb snd_square
			fcb 1
			fcb 6,192,0,64,32
			fdb snd_square
			fcb 0

SND_ALERT2	fcb 20,192,0,24,3
			fdb snd_square
			fcb 1
			fcb 20,192,0,24,3
			fdb snd_square
			fcb 0

SND_WARPOUT	fcb 24,192,-8,192,2
			fdb snd_square
			fcb 1
			fcb 191,128,0,16,2
			;fcb 191,128,0,32,1
			fdb snd_square
			fcb 0

SND_EXPL2	fcb 8,192,-7,240,-7
			fdb snd_noise
			fcb 1
			fcb 36,255,-7,240,-7
			fdb snd_noise
			fcb 0

