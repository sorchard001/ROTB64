;**********************************************************
; Tiledriver Background Engine
; Copyright 2014-2017 S. Orchard
;**********************************************************

;these should be defined somewhere in project
;TD_SBUFF		equ $5400	; start of shift buffers
;TD_TILEROWS	equ 11		; number of rows of tiles


TD_LR_INC		equ 1		; number of pixels to scroll left/right

;**********************************************************

	section "DPVARS"

td_bptr		rmb 2	; offset of origin within shift buffers
td_hcoord	rmb 1	; horizontal pixel offset
td_vcoord	rmb 1	; vertical pixel offset
td_mptr		rmb 2	; pointer to map row
td_mptroff	rmb 1	; 2*horizontal offset to add to map pointer
					; (lsb indicates which half of tile)
td_sbuf		rmb 2	; pointer to current shift buffer (copy source)
td_fbuf		rmb 2	; pointer to current frame buffer (copy dest)
td_count	rmb 1	; general purpose counter
td_count2	rmb 1	; general purpose counter
td_temp		rmb 2	; general purpose temporary

; Pointers to left tile address buffers
td_addr_buf_l_ptr0	rmb 2
td_addr_buf_l_ptr1	rmb 2
td_addr_buf_l_ptr2	rmb 2

; Pointers to right tile address buffers
td_addr_buf_r_ptr0	rmb 2
td_addr_buf_r_ptr1	rmb 2
td_addr_buf_r_ptr2	rmb 2

;**********************************************************

	section "DATA"

; Tile address buffers
td_addr_buf		rmb (TD_TILEROWS+1)*12
td_addr_buf_end

;**********************************************************

TD_SBSIZE	equ TD_TILEROWS*256
TD_SBEND	equ TD_SBUFF + TD_SBSIZE*4

;**********************************************************

	section "RUN_ONCE"

td_init
	clra
	clrb
	std td_hcoord	; also clears td_vcoord
	std td_bptr

	ldx #MAPSTART
	stx td_mptr
	clr td_mptroff

	ldx #TD_SBUFF
	stx td_sbuf
	
	; initialise left/right address buffer pointers
	ldb #6
	ldx #td_addr_buf
	ldu #td_addr_buf_l_ptr0
1	stx ,u++
	leax (TD_TILEROWS+1)*2,x
	decb
	bne 1b

	rts

	
	section "CODE"

	include "td_updown.asm"
	include "td_leftright.asm"
	include "td_copybuf.asm"
	;include "td_copybuf_adv.asm"

