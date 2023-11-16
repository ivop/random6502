CC ?= gcc
CFLAGS ?= -O3 -W -Wall
LDFLAGS ?=
LIBS = -ltestu01

all: rnddata testu01

rnddata: rnddata.c
	$(CC) $(CFLAGS) -o rnddata rnddata.c

testu01:
	$(CC) $(CFLAGS) $(LDFLAGS) -o testu01 testu01.c $(LIBS)

clean:
	rm -f rnddata testu01 *~
