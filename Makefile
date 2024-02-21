#X11LIBDIR = /usr/X11R6/lib
PASCALCOMPILER = fpc
CC = gcc
CFLAGS = -O2 -g

POBJS =	puff.o pfart.o pffft.o pfmsc.o pfrw.o pfst.o pfun1.o pfun2.o pfun3.o xgraph.o

puff: puff_c.o ppas.sh
	sed -E 's/link([0-9]*).res/link\1.res puff_c.o -lX11/' <ppas.sh  >ppasx.sh
	sh ppasx.sh

%.o:	%.pas
	$(PASCALCOMPILER) -g $< -Cn

ppas.sh:	puff.pas
	$(PASCALCOMPILER) -g -s -a puff.pas

# version: 20160612

clean:
	rm -rf puff
	rm -rf *.o
	rm -rf *.s
	rm -rf *.ppu
	rm -rf *.res
	rm -rf ppas.sh ppasx.sh
