MADS ?= mads
CC ?= cc
CFLAGS ?= -O3 -W -Wall -Wextra
LDFLAGS ?=
LIBS ?=

all: emu_test

emu_test: emu_test.c emu_test.img
	$(CC) $(CFLAGS) $(LDFLAGS) -o emu_test emu_test.c $(LIBS)

emu_test.img: emu_test.s
	$(MADS) -o:emu_test.img emu_test.s

clean:
	rm -f emu_test emu_test.img *~
