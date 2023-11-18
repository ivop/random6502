#include <stdio.h>
#include <stdint.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include "MCS6502.h"

struct _MCS6502ExecutionContext cpu;

/* ------------------------------------------------------------------------ */

static char *algorithms[] = {
    "single_eor",
    "four_taps_eor",
    "sfc16",
    "chacha20(8)",
    "chacha20(12)",
    "chacha20(20)",
    "jsf32",
    "arbee",
    "arbee8"
};

static const int nalgorithms = sizeof(algorithms)/sizeof(char*);

/* ------------------------------------------------------------------------ */

static uint8_t memory[65536];

#define SEED_LOCATION 0xf000

#define SPEED_SIZE 100000
static uint8_t speed[SPEED_SIZE];

/* ------------------------------------------------------------------------ */

static uint8_t memory_read(uint16_t addr, void *ctx) {
    if (addr == 0xdd0d)
        memory[addr] = 0;
    return memory[addr];
}

/* ------------------------------------------------------------------------ */

static void memory_write(uint16_t addr, uint8_t value, void *ctx) {
    memory[addr] = value;
}

/* ------------------------------------------------------------------------ */

static int cpu_jsr(uint16_t newpc) {
    int cycles = 0;

    cpu.pc = newpc;
    while (cpu.pc != newpc+3) {
        MCS6502ExecNext(&cpu);
        cycles += cpu.timingForLastOperation;
    }
#if 0
    uint16_t addr = 0;

    pins = M6502_SYNC;
    M6502_SET_ADDR(pins, newpc);
    M6502_SET_DATA(pins, memory[newpc]);
    m6502_set_pc(&cpu, newpc);

    while (run--) {
        pins = m6502_tick(&cpu, pins);
        cycles++;

        addr = M6502_GET_ADDR(pins);

        if (pins & M6502_RW) {
            M6502_SET_DATA(pins, memory_read(addr));
        } else {
            memory_write(addr, M6502_GET_DATA(pins));
        }

        if (memory[m6502_pc(&cpu)] == 0xea) run = 1; // one cycle to complete
                                                     // possible pending write
    }
#endif
    return cycles;     // subtaract jsr/rts
}

/* ------------------------------------------------------------------------ */

// untested
static void swap_endian(void *q, int wordsize, int length) {
    uint8_t *p = q;
    uint8_t t;
    while (length--) {
        switch (wordsize) {
        case 2: t=p[0]; p[0]=p[1]; p[1]=t; break;
        case 4: t=p[0]; p[0]=p[1]; p[1]=p[2]; p[2]=p[3]; p[3]=t; break;
        case 8: t=p[0]; p[0]=p[1]; p[1]=p[2]; p[2]=p[3]; p[3]=p[4];
                p[4]=p[5]; p[5]=p[6]; p[6]=p[7]; p[7]=t; break;
        default:
            fprintf(stderr, "ERROR: endian swap for wordsize %d not implemented!\n", wordsize);
            exit(1);
        }
        p += wordsize;
    }
}

/* ------------------------------------------------------------------------ */

static void usage(char *name) {
    fprintf(stderr,
            "%s: usage: %s algorithm length > filename\n"
            "\n"
            "\talgorithms:\n",
            name, name);
    for (int i=0; i<nalgorithms; i++)
        fprintf(stderr, "\t\t%d. %s\n", i, algorithms[i]);
    fprintf(stderr, "\n\tlength:\t[0 ... %lld]\n", LLONG_MAX);
    fprintf(stderr, "\n");
}

/* ------------------------------------------------------------------------ */

int main(int argc, char **argv) {
    int cycles, mincycles = INT_MAX, maxcycles = 0;
    long long int total = 0;
    volatile int test = 1;
    bool big_endian = false;

    big_endian = *((char *)&test) != 1;

    fprintf(stderr, "%s: host is %s endian\n", argv[0], big_endian ? "big" : "little");

    if (argc != 3) {
        usage(argv[0]);
        return 1;
    }

    int algo = atoi(argv[1]);
    long long int length = atoll(argv[2]);

    if (algo < 0 || algo >= nalgorithms) {
        fprintf(stderr, "%s: algorithm out of range [0..%d]\n", argv[0],
                                                            nalgorithms-1);
        return 1;
    }

    if (length < 0) {
        fprintf(stderr, "%s: error: negative length\n", argv[0]);
        return 1;
    }

    fprintf(stderr, "%s: testing %s\n", argv[0], algorithms[algo]);

    MCS6502Init(&cpu, memory_read, memory_write, NULL);

    FILE *f = fopen("emu_test.img", "rb");

    if (!f) {
        fprintf(stderr, "%s: error: unable to open 'emu_test.img'\n", argv[0]);
        return 1;
    }

    int size = fread(memory+0x0200, 1, 65536-0x0200, f);
    fclose(f);

    fprintf(stderr, "%s: read %d bytes to 0x0200\n", argv[0], size);

    switch (algo) {
    case 0:
    case 1:
        cpu.a = 0xff;
        break;
    case 2: {
        uint16_t seed[] = { 0xd33e, 0x607e, 0x834a, 0x517a };
        if (big_endian) swap_endian(seed, 2, 4);
        memcpy(memory+SEED_LOCATION, seed, 4*2);
        cpu.a = SEED_LOCATION & 0xff;
        cpu.x = SEED_LOCATION >> 8;
        break;
        }
    case 3:
    case 4:
    case 5: {
        uint32_t seed[] = {
            0x93ba769e, 0xcf1f833e, 0x06921c46, 0xf57871ac,
            0x363eca41, 0x766a5537, 0x04e7a5dc, 0xe385505b,
            0, 0,
            0x81a3749a, 0x7410533d
        };
        if (big_endian) swap_endian(seed, 4, 12);
        memcpy(memory+SEED_LOCATION, seed, 12*4);
        cpu.a = SEED_LOCATION & 0xff;
        cpu.x = SEED_LOCATION >> 8;
        break;
        }
    case 6: {
        uint64_t seed = 0xdeadbeefb01dface;
        if (big_endian) swap_endian(&seed, 8, 1);
        memcpy(memory+SEED_LOCATION, &seed, 8);
        cpu.a = SEED_LOCATION & 0xff;
        cpu.x = SEED_LOCATION >> 8;
        break;
        }
    case 7: {
        uint64_t seed[] = { 1, 1, 1, 1 };
        if (big_endian) swap_endian(seed, 8, 4);
        memcpy(memory+SEED_LOCATION, &seed, 8*4);
        cpu.a = SEED_LOCATION & 0xff;
        cpu.x = SEED_LOCATION >> 8;
        break;
        }
    default:
        fprintf(stderr, "%s: error: algorithm %d not implemented yet\n",
                                                            argv[0], algo);
        return 1;
    }

    cycles = cpu_jsr(0x0200+algo*8);
    fprintf(stderr, "%s: seeding took %d cycles\n", argv[0], cycles-3);

    for (long long int i=0; i<length; i++) {
        cycles = cpu_jsr(0x0200+algo*8+4);
        if (cycles >= SPEED_SIZE) cycles = SPEED_SIZE-1;
        speed[cycles] = 1;
        total += cycles;
        putc(cpu.a, stdout);
    }

    for (int i=0; i<SPEED_SIZE; i++) {
        if (speed[i]) {
//            fprintf(stderr, "%s: a call to random took %d cycles\n", argv[0], i);
            if (i<mincycles) mincycles = i;
            if (i>maxcycles) maxcycles = i;
        }
    }

    fprintf(stderr, "%s: min: %d cycles\n", argv[0], mincycles);
    fprintf(stderr, "%s: max: %d cycles\n", argv[0], maxcycles);
    fprintf(stderr, "%s: average: %d cycles\n", argv[0], (int)(total/length));
}
