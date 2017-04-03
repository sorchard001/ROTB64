
 if !__STDMACROS
__STDMACROS equ 1

assert	macro
	if !(\1)
	tst __\2
	endif
 endm

align	macro
	; have to use '&1' form of parameter within string?
	assert (\1 != 0) && ((\1 & (\1 - 1)) == 0), "align_arg_not_pwr2__<&1>"
	org * + (-* & (\1-1))
 endm
	
 
 
 endif

	