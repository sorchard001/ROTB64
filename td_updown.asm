;**********************************************************
; Tiledriver Background Engine
; Copyright 2014-2017 S. Orchard
;**********************************************************
;
; Scroll up or down
;
; Vertical scrolling is achieved by adjusting the buffer
; pointer one row up or down and then drawing a horizontal
; stripe into all four background buffers. Each version
; of the stripe has the appropriate degree of shift to
; suit the destination buffer.
;
; When scrolling up, the stripe is drawn at the buffer pointer
; so that the new data appears at the top of the screen. When
; scrolling down the data is drawn at buffer pointer - buffer width
; (i.e. the old position of the pointer)
; The buffer pointer is wrapped to stay in the buffer.
;
; When a new row of tiles comes into view:
;  The map pointer is moved to a new map row
;  The left & right address buffers are scrolled one row
;  Addresses from the new row are stored in the left & right buffers
;
; TODO:
; Reduce number of tile address calculations
;   Calculate once per tile, not every line (Only worth doing for vertical only scrolling)
;	Address calculations for left/right buffers are duplicated
;**********************************************************

	section "CODE"

;*************************************
; move up
;*************************************

td_scroll_up

	; buffer pointer 1 line up
	ldd td_bptr
	subd #32
	bhs 1f
	addd #TD_SBSIZE
1	std td_bptr


	; if moving into new tile then move map pointer up
	lda td_vcoord
	bita #7
	lbne 1f

	ldd td_mptr
	subd #MAPWID
	cmpd #MAPSTART
	bhs 2f
	addd #MAPSIZE
2	std td_mptr

	; scroll left/right tile address buffers (data is moved up in memory)
	; works for arbitrary number of rows because each row requires 12 bytes of addresses
	sts 8f+2
	lds #td_addr_buf_end
9	leau -8,s
	pulu d,x,y
	pshs d,x,y
	leau -8,s
	pulu d,x,y
	pshs d,x,y
	cmps #td_addr_buf+2
	bhi 9b
8	lds #0
	
	; fill new positions in left/right tile address buffers
	ldx td_mptr

	ldb td_mptroff
	decb
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda #(TILES & $ff)>>1
	rola
	sta 10f+2	; Modify tile base addresses
	sta 12f+2
	sta 14f+2
	eora #1
	sta 11f+2
	sta 13f+2
	sta 15f+2

	lda b,x
	ldb #16
	mul
10	addd #TILES		; Modified depending which half of tile
	std [td_addr_buf_l_ptr2]

	ldb td_mptroff
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
11	addd #TILES		; Modified depending which half of tile
	std [td_addr_buf_l_ptr0]

	ldb td_mptroff
	incb
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
12	addd #TILES		; Modified depending which half of tile
	std [td_addr_buf_l_ptr1]

	ldb td_mptroff
	addb #30
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
13	addd #TILES		; Modified depending which half of tile
	std [td_addr_buf_r_ptr2]

	ldb td_mptroff
	addb #31
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
14	addd #TILES		; Modified depending which half of tile
	std [td_addr_buf_r_ptr0]

	ldb td_mptroff
	addb #32
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
15	addd #TILES		; Modified depending which half of tile
	std [td_addr_buf_r_ptr1]

	
	; get address of tile data
	lda td_vcoord
1	suba #1
	sta td_vcoord
	ldu #TILES
	anda #7
	lsla
	leau a,u

	; position to start drawing
	ldx td_bptr
	leax TD_SBUFF,x
	stx td_draw_ud_shifted+1
	
	; map row
	ldy td_mptr

	lda td_mptroff
	lsra
	lbcc td_draw_ud_even
	jmp td_draw_ud_odd

	
;*************************************
; move down
;*************************************

td_scroll_down

	; buffer pointer 1 line down
	ldd td_bptr
	std td_draw_d_pos		; save address for draw start pos
	addd #32
	cmpd #TD_SBSIZE
	blo 1f
	subd #TD_SBSIZE
1	std td_bptr

	; if moving into new tile then move map pointer down
	lda td_vcoord
	adda #1
	sta td_vcoord
	bita #7
	lbne 1f

	ldx td_mptr
	leax MAPWID,x
	cmpx #MAPEND
	blo 2f
	leax -MAPSIZE,x
2	stx td_mptr

	; scroll left/right tile address buffers (data is moved down in memory)
	; works for arbitrary number of rows because each row requires 12 bytes of addresses
	sts 8f+2
	ldu #td_addr_buf+2
9	pulu d,x,y
	leas -2,u
	pshs d,x,y
	pulu d,x,y
	leas -2,u
	pshs d,x,y
	cmpu #td_addr_buf_end
	blo 9b
8	lds #0
	
	; fill new positions in tile address buffers
	ldx td_mptr
	leax TD_TILEROWS*MAPWID,x
	cmpx #MAPEND
	blo 9f
	leax -MAPSIZE,x
9
	ldb td_mptroff
	decb
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda #(TILES & $ff)>>1
	rola
	sta 10f+2	; Modify tile base addresses
	sta 12f+2
	sta 14f+2
	eora #1
	sta 11f+2
	sta 13f+2
	sta 15f+2

	lda b,x
	ldb #16
	mul
10	addd #TILES		; Modified depending which half of tile
	ldu td_addr_buf_l_ptr2
	std TD_TILEROWS*2,u

	ldb td_mptroff
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
11	addd #TILES		; Modified depending which half of tile
	ldu td_addr_buf_l_ptr0
	std TD_TILEROWS*2,u

	ldb td_mptroff
	incb
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
12	addd #TILES		; Modified depending which half of tile
	ldu td_addr_buf_l_ptr1
	std TD_TILEROWS*2,u

	ldb td_mptroff
	addb #30
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
13	addd #TILES		; Modified depending which half of tile
	ldu td_addr_buf_r_ptr2
	std TD_TILEROWS*2,u

	ldb td_mptroff
	addb #31
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
14	addd #TILES		; Modified depending which half of tile
	ldu td_addr_buf_r_ptr0
	std TD_TILEROWS*2,u

	ldb td_mptroff
	addb #32
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	lda b,x
	ldb #16
	mul
15	addd #TILES		; Modified depending which half of tile
	ldu td_addr_buf_r_ptr1
	std TD_TILEROWS*2,u

	
	; get address of tile data
	lda td_vcoord
1	ldu #TILES
	adda #7
	anda #7
	lsla
	leau a,u

	; position to start drawing
td_draw_d_pos equ *+1
	ldx #0	
	leax TD_SBUFF,x
	stx td_draw_ud_shifted+1

	; map row
	ldy td_mptr
	leay TD_TILEROWS*MAPWID,y
	lda td_vcoord
	bita #7
	bne 1f
	leay -MAPWID,y	; adjust if drawing last row of tile
1	cmpy #MAPEND
	blo 1f
	leay -MAPSIZE,y
1
	lda td_mptroff
	lsra
	bcc td_draw_ud_even
	jmp td_draw_ud_odd

;*************************************

td_draw_ud_even

	; position of map data
	lda td_mptroff
	lsra
	sta 5f+2

	lda #2				; do in two chunks to insert two dac updates
	sta td_count2		;
	
3	lda #8
	sta td_count
2	
	; point to tile data
5	lda <0,y
	ldb #16
	mul
	ldd d,u
	std ,x++
	cmpx #TD_SBUFF+TD_SBSIZE
	blo 1f
	ldx #TD_SBUFF ;leax -TD_SBSIZE,x
1	
	lda 5b+2
	inca
	anda #(MAPWID-1)
	sta 5b+2

	dec td_count
	bne 2b

	ldb [snd_buf_ptr]	; update dac
	stb $ff20			;
	inc snd_buf_ptr+1	;

	dec td_count2
	bne 3b
	
	; LH byte from 17th tile is required for shifted buffers
	lda a,y
	ldb #16
	mul
	lda d,u
	sta td_ud_shifted_byte33+1

	jmp td_draw_ud_shifted
	
	
td_draw_ud_odd

	; position of map data
	lda td_mptroff
	lsra
	pshs a

	; RH byte of 1st tile
	lda a,y
	ldb #16
	mul
	ldd d,u
	stb ,x+
	cmpx #TD_SBUFF+TD_SBSIZE
	blo 1f
	ldx #TD_SBUFF ;leax -TD_SBSIZE,x
1	
	puls a
	inca
	anda #(MAPWID-1)
	sta 5f+2

	; 15 x complete tiles
	; do in two chunks to insert two dac updates
	lda #2
	sta td_count2
	
	lda #8			; 8 tiles, then 7 tiles
3	sta td_count
2	
5	lda <0,y
	ldb #16
	mul
	ldd d,u
	std ,x++
	cmpx #TD_SBUFF+TD_SBSIZE
	blo 1f
	ldx #TD_SBUFF ;leax -TD_SBSIZE,x
1	
	lda 5b+2
	inca
	anda #(MAPWID-1)
	sta 5b+2
	
	dec td_count
	bne 2b

	ldb [snd_buf_ptr]	; update dac
	stb $ff20			;
	inc snd_buf_ptr+1	;

	dec td_count2
	beq 3f
	lda #7
	bra 3b

	; LH byte of 17th tile
3	lda a,y
	ldb #16
	mul
	ldd d,u
	sta ,x

	; RH byte required for shifted buffers
	stb td_ud_shifted_byte33+1

	; fall through

;**********************************************************
; Copy and shift line from zero shift buffer to other buffers
;**********************************************************

td_draw_ud_shifted
	; point to source data (modified by caller)
	ldx #0

	lda #2			; do in two chunks to insert 2 dac updates
	sta td_count	;
	
	ldy #15			; (15 bytes, then 16 bytes next time)
 	
2	cmpx #TD_SBUFF+TD_SBSIZE-1	; check if near wrap boundary
	blo 3f						; not at boundary: ok to load word
	bne 4f						; after boundary: wrap then load word
	lda ,x+						; else boundary in middle of word
	ldb TD_SBUFF ;ldb -TD_SBSIZE,x
	bra 1f
4	ldx #TD_SBUFF ;leax -TD_SBSIZE,x
3	ldd ,x+

1	lslb
	rola
	lslb
	rola
	sta TD_SBSIZE-1,x
	lslb
	rola
	lslb
	rola
	sta 2*TD_SBSIZE-1,x
	lslb
	rola
	lslb
	rola
	sta 3*TD_SBSIZE-1,x

	leay -1,y
	bne 2b

	lda [snd_buf_ptr]	; update dac
	sta $ff20			;
	inc snd_buf_ptr+1	;
	
	dec td_count
	beq 1f
	ldy #16
	bra 2b
	
1	
	cmpx #TD_SBUFF+TD_SBSIZE
	blo 2f
	ldx #TD_SBUFF ;leax -TD_SBSIZE,x
2	
	lda ,x
td_ud_shifted_byte33
	ldb #0		; modified by caller
	lslb
	rola
	lslb
	rola
	sta TD_SBSIZE,x
	lslb
	rola
	lslb
	rola
	sta 2*TD_SBSIZE,x
	lslb
	rola
	lslb
	rola
	sta 3*TD_SBSIZE,x

	rts

