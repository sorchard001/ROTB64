;**********************************************************
; ROTB - Return of the Beast
; Copyright 2014-2017 S. Orchard
;**********************************************************

; velocity scale factors
VSX	equ 64/256
VSY	equ 32/256

; macro to create a velocity table for 16 directions (22.5 degree steps)
; parameter defines speed in pixels per frame.
; first entry is east, subsequent entries counterclockwise.
mac_velocity_table	macro

1	equ 98 * \1
2	equ 181 * \1
3	equ 236 * \1
4	equ 256 * \1

	fdb  4b*VSX,  0
	fdb  3b*VSX, -1b*VSY
	fdb  2b*VSX, -2b*VSY
	fdb  1b*VSX, -3b*VSY
	fdb  0,      -4b*VSY
	fdb -1b*VSX, -3b*VSY
	fdb -2b*VSX, -2b*VSY
	fdb -3b*VSX, -1b*VSY

	fdb -4b*VSX,  0
	fdb -3b*VSX,  1b*VSY
	fdb -2b*VSX,  2b*VSY
	fdb -1b*VSX,  3b*VSY
	fdb  0,       4b*VSY
	fdb  1b*VSX,  3b*VSY
	fdb  2b*VSX,  2b*VSY
	fdb  3b*VSX,  1b*VSY

	endm


; macro to create a velocity table for 16 directions (22.5 degree steps)
; parameter defines speed in pixels per frame.
; first entry is west, subsequent entries counterclockwise.
; (rotated 180 degrees compared to player directions)
mac_velocity_table_180	macro

1	equ 98 * \1
2	equ 181 * \1
3	equ 236 * \1
4	equ 256 * \1

	fdb -4b*VSX,  0
	fdb -3b*VSX,  1b*VSY
	fdb -2b*VSX,  2b*VSY
	fdb -1b*VSX,  3b*VSY
	fdb  0,       4b*VSY
	fdb  1b*VSX,  3b*VSY
	fdb  2b*VSX,  2b*VSY
	fdb  3b*VSX,  1b*VSY
	fdb  4b*VSX,  0
	fdb  3b*VSX, -1b*VSY
	fdb  2b*VSX, -2b*VSY
	fdb  1b*VSX, -3b*VSY
	fdb  0,      -4b*VSY
	fdb -1b*VSX, -3b*VSY
	fdb -2b*VSX, -2b*VSY
	fdb -3b*VSX, -1b*VSY
	endm

