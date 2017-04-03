
_setpatch macro
	fcb setpatch,\1
	endm

	
_call	macro
	fcb call
	fdb \1
	endm


_return macro
	fcb return
	endm


_settp macro
	fcb settp,\1
	endm


_calltp	macro
	fcb calltp,\1
	fdb \2
	endm


_jump macro
	fcb jump
	fdb \1
	endm

	
_loop macro
	fcb loop,\1
	endm


_next macro
	fcb next
	endm


_setarp macro
	fcb	setarp,\1
	fdb \2
	endm

_setport macro
	fcb setport,\1
	endm
