; PIA0
reg_pia0_ddra		equ	$ff00
reg_pia0_pdra		equ	$ff00
reg_pia0_cra		equ	$ff01
reg_pia0_ddrb		equ	$ff02
reg_pia0_pdrb		equ	$ff02
reg_pia0_crb		equ	$ff03

; PIA1
reg_pia1_ddra		equ	$ff20
reg_pia1_pdra		equ	$ff20
reg_pia1_cra		equ	$ff21
reg_pia1_ddrb		equ	$ff22
reg_pia1_pdrb		equ	$ff22
reg_pia1_crb		equ	$ff23

; SAM register base
reg_sam_base		equ	$ffc0

; SAM VDG Mode
reg_sam_v0c		equ	$ffc0
reg_sam_v0s		equ	$ffc1
reg_sam_v1c		equ	$ffc2
reg_sam_v1s		equ	$ffc3
reg_sam_v2c		equ	$ffc4
reg_sam_v2s		equ	$ffc5

; SAM Display Offset
reg_sam_f0c		equ	$ffc6
reg_sam_f0s		equ	$ffc7
reg_sam_f1c		equ	$ffc8
reg_sam_f1s		equ	$ffc9
reg_sam_f2c		equ	$ffca
reg_sam_f2s		equ	$ffcb
reg_sam_f3c		equ	$ffcc
reg_sam_f3s		equ	$ffcd
reg_sam_f4c		equ	$ffce
reg_sam_f4s		equ	$ffcf
reg_sam_f5c		equ	$ffd0
reg_sam_f5s		equ	$ffd1
reg_sam_f6c		equ	$ffd2
reg_sam_f6s		equ	$ffd3

; SAM Memory Configuration
reg_sam_p1c		equ	$ffd4
reg_sam_p1s		equ	$ffd5
reg_sam_m0c		equ	$ffda
reg_sam_m0s		equ	$ffdb
reg_sam_m1c		equ	$ffdc
reg_sam_m1s		equ	$ffdd
reg_sam_tyc		equ	$ffde
reg_sam_tys		equ	$ffdf

; SAM MPU Rate
reg_sam_r0c		equ	$ffd6
reg_sam_r0s		equ	$ffd7
reg_sam_r1c		equ	$ffd8
reg_sam_r1s		equ	$ffd9
