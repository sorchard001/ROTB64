;**********************************************************
; Tiledriver Background Engine
; Copyright 2015 S. Orchard
;**********************************************************
;
; Scroll left or right
;
; Horizontal scrolling is achieved by selecting one of the
; four background buffers to match the desired degree of
; shift.
;
; Each time a byte boundary is crossed, the buffer pointer
; is adjusted left or right by one byte.
;
; A vertical stripe of data, 1 byte wide, is drawn into the
; current buffer. When scrolling left, this is drawn
; starting from the buffer pointer so that the new stripe
; appears at the left edge of the screen. When scrolling right,
; it is drawn at buffer pointer + buffer width - 1.
; The buffer pointer is wrapped to stay in the buffer.
; 
; Drawing into the zero shift buffer is the quickest.
; Drawing into the shifted buffers is much slower because
; 2 source bytes are required to make a shifted destination
; byte.
;
; To even out the workload, tile addresses are calculated
; on the zero-shift frames.
; There are 3 left address buffers and 3 right address buffers.
; After load levelling, the 2-shift frames are slowest.
; 0, 1 & 3-shift frames take similar amounts of time.
;
; The stripe is offset to suit the current vertical position
; and therefore consists of three fragments: Some or all
; rows of a tile at the top, a run of 'complete' tiles
; and some or no rows of a tile at the bottom.
;
;**********************************************************

	section "CODE"


; macro to check if x has moved past the end of the buffer
; and correct if necessary
;
td_check_bb_pos	macro
	cmpx #\1+TD_SBSIZE
	blo 99f
	leax -TD_SBSIZE,x
99
	endm

; macro to move y to point to the next row of the map.
; wraps back to the top of the map.
;	
td_next_map_row	macro
	leay MAPWID,y
	cmpy #MAPEND
	blo 99f
	leay -MAPSIZE,y
99
	endm

	
; macro to shift word left 0-3 colour pixels & store result at x
; \1 is pixel shift left 0-3
; \2 is store offset
;
td_pixel_shift_store	macro
	if (\1 == 0)
		if (\2 == 0)
		  sta ,x
		else
		  sta \2,x
		endif
	elsif (\1 == 1)
		lslb
		rola
		lslb
		rola
		if (\2 == 0)
		  sta ,x
		else
		  sta \2,x
		endif
	elsif (\1 == 2)
		lslb
		rola
		lslb
		rola
		lslb
		rola
		lslb
		rola
		if (\2 == 0)
		  sta ,x
		else
		  sta \2,x
		endif
	elsif (\1 == 3)
		lsra
		rorb
		lsra
		rorb
		if (\2 == 0)
		  stb ,x
		else
		  stb \2,x
		endif
	endif
	endm

;**********************************************************
; scroll left
;**********************************************************

td_scroll_left

	; if moving from buffer zero then need to move pointers
	lda td_hcoord
	ldb td_hcoord
	suba #TD_LR_INC
	sta td_hcoord
	bitb #3
	bne 1f

	; move buffer pointer 1 byte to left
	ldx td_bptr
	bne 2f
	ldx #TD_SBSIZE
2	leax -1,x
	stx td_bptr

	; move map pointer 1 byte to left
	ldb td_mptroff
	decb
	andb #(MAPWID*2-1)	; wrap horizontally
	stb td_mptroff
	
	; rotate tile address buffer pointers
	ldu #td_addr_buf_l_ptr0
	pulu d,x,y
	pshu d,x
	pshu y
	ldu #td_addr_buf_r_ptr0
	pulu d,x,y
	pshu d,x
	pshu y

	bra 5f
	
	; if moving to buffer zero then need to precalc tile addresses
1	bita #3
	bne 5f
	ldd #$ff1e		; A = left map offset, B = right map offset
	jsr td_lr_calc_addresses

5
	; offset in destination buffer to start drawing
	ldx td_bptr	

	; point to tile addresses
	ldy td_addr_buf_l_ptr0
	ldd td_addr_buf_l_ptr1
	subd td_addr_buf_l_ptr0
	stb td_temp

	; jump to required drawing routine
	lda td_hcoord
	anda #3
	lsla
	ldu #td_draw_shift_jmp_table
	jmp [a,u]

;**********************************************************
; scroll right
;**********************************************************

td_scroll_right

	lda td_hcoord
	adda #TD_LR_INC
	sta td_hcoord

	; if moving to buffer 0 then need to move pointers
	bita #3
	bne 5f

	; move buffer pointer 1 byte to right
	ldd td_bptr
	addd #1
	cmpd #TD_SBSIZE
	blo 1f
	clra
	clrb
1	std td_bptr

	; move map pointer 1 byte to right
	lda td_mptroff
	inca
	anda #(MAPWID*2-1)	; wrap horizontally
	sta td_mptroff

	; setup for address calculation
	ldd #$0120		; A = left map offset, B = right map offset
	bsr td_lr_calc_addresses

	; rotate tile address buffer pointers
	ldu #td_addr_buf_l_ptr0
	pulu d,x,y
	pshu d
	pshu x,y
	ldu #td_addr_buf_r_ptr0
	pulu d,x,y
	pshu d
	pshu x,y
	
5	
	; offset in destination buffer to start drawing
	ldx td_bptr	
	leax 31,x

	; point to tile addresses
	ldy td_addr_buf_r_ptr0
	ldd td_addr_buf_r_ptr1
	subd td_addr_buf_r_ptr0
	stb td_temp

	; jump to required drawing routine
	lda td_hcoord
	anda #3
	lsla
	ldu #td_draw_shift_jmp_table
	jmp [a,u]

	
;**********************************************************
; Calculate new tile addresses
;
; A contains map offset for new address at left edge of screen
; B contains map offset for new addresses at right edge
;**********************************************************

td_lr_calc_addresses

	sta 50f+1	; map offset for left edge
	stb 51f+1	; map offset for right edge

	; point to map data at left edge of buffer
	ldy td_mptr
	ldb td_mptroff
50	addb #1
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	leay b,y
	ldb #(TILES & $ff)>>1
	rolb
	stb 2f+2	; Mod tile base address for left edge
	eorb #1
	stb 4f+2	; Mod tile base address for right edge

	; calculate new tile addresses for left edge of buffer
	lda #TD_TILEROWS+1
	sta td_count
	ldx td_addr_buf_l_ptr2
3	lda ,y
	ldb #16
	mul
2	addd #TILES		; modified depending which half of tile
	std ,x++
	td_next_map_row
	dec td_count
	bne 3b

	; point to map data at right edge of buffer
	ldy td_mptr
	ldb td_mptroff
51	addb #32
	andb #(MAPWID*2-1)	; wrap horizontally
	lsrb
	leay b,y

	; calculate new tile addresses for right edge of buffer
	lda #TD_TILEROWS+1
	sta td_count
	ldx td_addr_buf_r_ptr2
3	lda ,y
	ldb #16
	mul
4	addd #TILES		; modified depending which half of tile
	std ,x++
	td_next_map_row
	dec td_count
	bne 3b

	rts

;**********************************************************
; draw vertical stripe of shifted bytes
;
; x is start position in buffer
; (x is possibly out of bounds so check/adjust first)
; y points to address buffer containing left tile fragments
; temp contains offset to buffer containing right tile fragments
;**********************************************************

td_draw_shift	macro

	; \1 is number of pixels to shift left (0, 1, 2 or 3)
	; \2 is destination buffer

td_drawsh\1
	clr td_temp+1
	ldd snd_buf_ptr		; write sound buffer pointer to local self mod var
	std 30f+1			;

	; position to start drawing in buffer
	ldd #\2
	std td_sbuf
	leax d,x

  if \1 != 0
	sts 9f+2		; save stack
  endif

	; draw partial tile at top (or whole tile)
  if \1 != 0
	lda td_temp		; offset to 2nd buffer
	lds a,y			; address of 2nd tile fragment
	sta 50f+3		; save buffer offset for loop
  endif
	ldu ,y++		; address of 1st tile fragment

	lda td_vcoord	; apply vertical offset to tile addresses
	anda #7
	tfr a,b
	lsla
	leau a,u
  if \1 != 0
	leas a,s
  endif
	subb #8
	negb
	stb td_count2
	
1	td_check_bb_pos \2
	lda ,u++
  if \1 != 0
	ldb ,s++
  endif
	td_pixel_shift_store \1,0
	leax 32,x
	dec td_count2
	bne 1b

	
	; draw full tiles

	lda #TD_TILEROWS-1
	sta td_count
5
	com td_temp+1		; update dac every 2 tiles
	bne 40f				;
30	lda >0				;
	sta $ff20			;
	inc 30b+2			;
40

  if \1 != 0
50	lds <0,y
  endif
	ldu ,y++
	
	; Check if tile contains buffer boundary
	cmpx #\2+TD_SBSIZE-32*8
	bls 2f					; draw tile without boundary check

	; slow tile draw (checks for buffer boundary)
	ldb #8
	stb td_count2
1	td_check_bb_pos \2
	lda ,u++
  if \1 != 0
	ldb ,s++
  endif
	td_pixel_shift_store \1,0
	leax 32,x
	dec td_count2
	bne 1b

	dec td_count
	bne 5b		; next tile
	jmp 3f

2	
	; fast tile draw (no check for buffer boundary)
	lda ,u
  if \1 != 0
	ldb ,s
  endif
	td_pixel_shift_store \1,0
	lda 2,u
  if \1 != 0
	ldb 2,s
  endif
	td_pixel_shift_store \1,32
	lda 4,u
  if \1 != 0
	ldb 4,s
  endif
	td_pixel_shift_store \1,64
	lda 6,u
  if \1 != 0
	ldb 6,s
  endif
	td_pixel_shift_store \1,96
	leax 256,x
	lda 8,u
  if \1 != 0
	ldb 8,s
  endif
	td_pixel_shift_store \1,-128
	lda 10,u
  if \1 != 0
	ldb 10,s
  endif
	td_pixel_shift_store \1,-96
	lda 12,u
  if \1 != 0
	ldb 12,s
  endif
	td_pixel_shift_store \1,-64
	lda 14,u
  if \1 != 0
	ldb 14,s
  endif
	td_pixel_shift_store \1,-32

	dec td_count
  if \1 != 0
	lbne 5b		; next tile
  else
	bne 5b
  endif

3	
	; draw partial tile at bottom (or not at all)
	ldb td_vcoord
	andb #7
	beq 2f
	stb td_count2

  if \1 != 0
	lda td_temp
	lds a,y
  endif
	ldu ,y++

1	td_check_bb_pos \2
	lda ,u++
  if \1 != 0
	ldb ,s++
  endif
	td_pixel_shift_store \1,0
	leax 32,x
	dec td_count2
	bne 1b
2
  if \1 != 0
9	lds #0		; restore stack
  endif

	ldb 30b+2			; update sound buffer pointer from local var
	stb snd_buf_ptr+1	; (only need to update low byte)
  
	rts

	endm

	
	td_draw_shift 0,TD_SBUFF
	td_draw_shift 1,TD_SBUFF+TD_SBSIZE
	td_draw_shift 2,TD_SBUFF+TD_SBSIZE*2
	td_draw_shift 3,TD_SBUFF+TD_SBSIZE*3

td_draw_shift_jmp_table
	fdb td_drawsh0, td_drawsh1, td_drawsh2, td_drawsh3

;**********************************************************
