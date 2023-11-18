#include <stdio.h>
#include <stdint.h>
#include <limits.h>
#include <stdlib.h>

#define CHIPS_IMPL
#include "m6502.h"

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

static m6502_t cpu;
static uint64_t pins;
static uint8_t memory[65536];

#define SPEED_SIZE 20000
static uint8_t speed[SPEED_SIZE];

static uint8_t memory_read(uint16_t addr) {
    if (addr == 0xdd0d)
        memory[addr] = 0;
    return memory[addr];
}

static void memory_write(uint16_t addr, uint8_t value) {
    memory[addr] = value;
}

static int cpu_jsr(uint16_t newpc) {
    int cycles = 0;

    pins = M6502_SYNC;
    M6502_SET_ADDR(pins, newpc);
    M6502_SET_DATA(pins, memory[newpc]);
    m6502_set_pc(&cpu, newpc);

    int run = INT_MAX;
    while (run--) {
        pins = m6502_tick(&cpu, pins);
        cycles++;

        const uint16_t addr = M6502_GET_ADDR(pins);

        if (pins & M6502_RW) {
            M6502_SET_DATA(pins, memory_read(addr));
        } else {
            memory_write(addr, M6502_GET_DATA(pins));
        }

        if (memory[m6502_pc(&cpu)] == 0x00) run = 1; // one cycle to complete
                                                     // possible pending write
    }

    return cycles - 1;
}

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

int main(int argc, char **argv) {
    int cycles;

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

    pins = m6502_init(&cpu, &(m6502_desc_t){});

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
        m6502_set_a(&cpu, 0xff);
        break;
    case 1:
        m6502_set_a(&cpu, 0xff);
        break;
    case 2: {
        uint16_t seed[] = { 0xd33e, 0x607e, 0x834a, 0x517a };
        memcpy(memory+0x8000, seed, 8);
        m6502_set_a(&cpu, 0x00);
        m6502_set_x(&cpu, 0x80);
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
        putc(m6502_a(&cpu), stdout);
    }

    for (int i=0; i<SPEED_SIZE; i++) {
        if (speed[i])
            fprintf(stderr, "%s: a call to random took %d cycles\n", argv[0], i-1);
    }
}
