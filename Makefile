# rotb Makefile
# S. Orchard 2017

PRJ=rotb

ASM6809=asm6809 -v

.PHONY: all
all: $(PRJ).bin

# lazy rule: target depends on all source files present
$(PRJ).bin: *.asm *.s
	$(ASM6809) -D -l $(PRJ).lst -o $@ $(PRJ).asm

%.cas %.wav: %.bin
	#bin2cas.pl -r 22050 -o $@ -D $<
	bin2cas.pl --autorun -z --fast -r 22050 -o $@ -D $<

# coords.asm generated from script
$(PRJ).bin: coords.asm
coords.asm: calc_coords.py
	./calc_coords.py


.PHONY: clean
clean:
	rm -f $(PRJ).bin
	rm -f $(PRJ).lst
	rm -f $(PRJ).wav
	rm -f $(PRJ).cas

