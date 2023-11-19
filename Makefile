MADS ?= mads
CC ?= cc
CFLAGS ?= -O3 -W -Wall -Wextra
LDFLAGS ?=
LIBS ?=

all: emu_test

emu_test: emu_test.c MCS6502.c MCS6502.h emu_test.img
	$(CC) $(CFLAGS) $(LDFLAGS) -o emu_test emu_test.c MCS6502.c $(LIBS)

emu_test.img: emu_test.s random.s macros.s
	$(MADS) -o:emu_test.img emu_test.s

atari: atari_test1.xex atari_test2.xex atari_test.s random.s macros.s

atari_test1.xex: random.s atari_test.s macros.s
	$(MADS) -d:TEST_BATCH1 -o:atari_test1.xex atari_test.s

atari_test2.xex: random.s atari_test.s macros.s
	$(MADS) -d:TEST_BATCH2 -o:atari_test2.xex atari_test.s

clean:
	rm -f emu_test emu_test.img atari_test1.xex atari_test2.xex *~
