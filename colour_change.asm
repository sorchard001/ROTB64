;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

;**********************************************************
; Simulation of palette by changing pixel colours
;
; Four bytes contain the current palette
; These initially contain 00,01,10,11 (grn, yel, blu, red)
;
; Each alternate palette is packed into a byte DDCCBBAA
; AA is the new colour[0], BB is colour[1] etc.
; i.e. after the palette change the palette bytes will be AA,BB,CC,DD
;
; A 4 byte mapping table is created.
; The current palette decides where in the map the new colours go e.g.:
;  Current palette 00,01,10,11 -> map AA,BB,CC,DD
;  Current palette 11,01,10,00 -> map DD,BB,CC,AA
;
; A 256 byte lookup table is created from the map.
; This is used to change the bytes in the target.
; If the map contains AA,BB,CC,DD then the lookup table starts like this:
; AAAAAAAA, AAAAAABB, AAAAAACC, AAAAAADD, AAAABBAA, AAAABBBB, AAAABBCC, ...
;
; If two or more colours in the new palette are the same
; then the conversion will be lossy.
; (This is OK if the original data can be restored from somewhere)
;
;**********************************************************

	section "DPVARS"

next_colour_set	rmb 2	; pointer to palette


	section "DATA"

current_pal_tiles 	rmb 4


	section "CODE"

; store GREEN,YELLOW,BLUE,RED in palette
colour_change_init
	ldd #colour_set_table
	std next_colour_set
	ldx #current_pal_tiles+4
	lda #3
1	sta ,-x
	deca
	bpl 1b
	rts

; create 256 byte lookup table
; X points to current palette
; A contains new palette
; returns with Y pointing to middle of lookup table
setup_colour_change_table

	ldu td_fbuf		; use screen buffer for storage while nobody is looking
	sta temp1		; palette for unpacking

	; determine new colour mapping
	;
	lda #4
	sta temp0
1	lda ,x		; current palette entry
	ldb temp1	; get new colour for palette entry
	andb #3		;
	stb ,x+		; update palette entry
	stb a,u		; store in new mapping
	lsr temp1	; shift next packed colour
	lsr temp1	;
	dec temp0
	bne 1b

	; generate 256 byte lookup table

	leay 4+128,u	; point to middle of lookup table
	clr temp0

5	lda temp0
	ldx #4		; 4 pixels per byte
1	clrb		; get one pixel from A into B
	lsla		;
	rolb		;
	lsla		;
	rolb		;
	ora b,u		; put recoloured pixel back into A
	leax -1,x	;
	bne 1b		; next pixel
2	sta <0,y	; use offset instead of auto-inc to get required layout
	inc 2b+2	; (note 256 byte table means offset returns to 0)
	inc temp0
	bne 5b		; next byte
	rts


; apply next palette to tile data and shift buffers
colour_change
	ldx next_colour_set
colour_change_x
	lda ,x+
	cmpx #colour_set_table_end
	blo 1f
	leax (colour_set_table-colour_set_table_end),x
1	stx next_colour_set

	ldx #current_pal_tiles
	jsr setup_colour_change_table
	; y is now pointing to middle of lookup table

	ldx #TILES
	ldd #TILEEND
	bsr _colour_change_sub
	ldx #TD_SBUFF
	ldd #TD_SBEND
	; fall through to _colour_change_sub

_colour_change_sub
	std 2f+1
1	ldd ,x
	lda a,y
	ldb b,y
	std ,x++	; assumes we're writing an even number of bytes
2	cmpx #0
	blo 1b
	rts


GREEN	equ 0
YELLOW	equ 1
BLUE	equ 2
RED		equ 3

colour_set_entry	macro
	fcb \4*64 + \3*16 + \2*4 + \1
  endm

	;fcb \1*64 + \2*16 + \3*4 + \4

colour_set_table
					; misc, land bright, water, land dark
	colour_set_entry RED, YELLOW, BLUE, GREEN
	colour_set_entry GREEN, YELLOW, RED, BLUE
	colour_set_entry BLUE, YELLOW, GREEN, RED
	colour_set_entry BLUE, YELLOW, RED, GREEN
	colour_set_entry RED, YELLOW, GREEN, BLUE
	colour_set_entry YELLOW, GREEN, RED, BLUE
	colour_set_entry YELLOW, GREEN, BLUE, RED
	colour_set_entry GREEN, YELLOW, BLUE, RED

colour_set_table_end

