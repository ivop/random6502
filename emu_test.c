#include <stdio.h>
#include <stdint.h>
#include <limits.h>

#define CHIPS_IMPL
#include "m6502.h"

static m6502_t cpu;
static uint64_t pins;
static uint8_t memory[65536];

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

        if (memory[m6502_pc(&cpu)] == 0x60) run = 1; // one cycle to complete
                                                     // possible pending write
    }

    return cycles;
}

int main(int argc, char **argv) {
    uint64_t pins = m6502_init(&cpu, &(m6502_desc_t){});

    FILE *f = fopen("emu_test.img", "rb");

    if (!f) {
        fprintf(stderr, "%s: error: unable to open 'emu_test.img'\n", argv[0]);
        return 1;
    }

    int size = fread(memory+0x0200, 1, 65536-0x0200, f);
    fclose(f);

    fprintf(stderr, "%s: read %d bytes to 0x0200\n", argv[0], size);

    m6502_set_a(&cpu, 0xff);
    int cycles = cpu_jsr(0x0200);

    fprintf(stderr, "%s: seeding took %d cycles\n", argv[0], cycles);

    for (int i=0; i<4096; i++) {
        cycles = cpu_jsr(0x0200+3);
        putc(m6502_a(&cpu), stdout);
    }

    fprintf(stderr, "%s: a single call to random took %d cycles\n", argv[0], cycles);
}
