#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

/* ---------------------------------------------------------------------- */

static char *algorithms[] = {
    "single_eor",
    "four_taps_eor",
    "sfc16",
    "chacha20(8)",
    "chacha20(12)",
    "chacha20(20)"
};

static const int nalgorithms = sizeof(algorithms)/sizeof(char*);

/* ---------------------------------------------------------------------- */

struct random_single_eor_ctx {
    uint8_t seed;
};

static void random_single_eor_seed(struct random_single_eor_ctx *ctx, uint8_t seed) {
    ctx->seed = seed;
}

static uint8_t random_single_eor(struct random_single_eor_ctx *ctx) {
    int A = ctx->seed;
    int C = 0;
    bool skipeor = false;

    if (A) {
        A <<= 1;
        C = !!(A & 0x0100);
        A &= 0xff;

        if (!A || !C) skipeor = true;
    }

    if (!skipeor) A ^= 0x1d;

    ctx->seed = A;

    return A;
}

/* ---------------------------------------------------------------------- */

struct random_four_taps_eor_ctx {
    uint8_t seed;
};

static void random_four_taps_eor_seed(struct random_four_taps_eor_ctx *ctx, uint8_t seed) {
    ctx->seed = seed;
}

static uint8_t random_four_taps_eor(struct random_four_taps_eor_ctx *ctx) {
    int A, Y = 0, M;

    A  = ctx->seed;
    A &= 0b10111000;
    M  = 0b10000000;

    for (int i=0; i<5; i++) {
        if (A & M) Y++;
        M >>= 1;
    }

    A = (ctx->seed << 1) | (Y&1);
    ctx->seed = A;

    return A;
}

/* ---------------------------------------------------------------------- */

struct random_sfc16_ctx {
    uint16_t A, B, C, counter, tmp;
    bool buffered;
};

static void random_sfc16_seed(struct random_sfc16_ctx *ctx, uint16_t seed[]) {
    ctx->A = seed[0];
    ctx->B = seed[1];
    ctx->C = seed[2];
    ctx->counter = seed[3];
}

static uint8_t random_sfc16(struct random_sfc16_ctx *ctx) {
    enum { RSHIFT = 5, LSHIFT = 3, BARREL_SHIFT = 6 };

    if (ctx->buffered) {
        ctx->buffered = false;
        return ctx->tmp >> 8;
    }

    ctx->tmp = ctx->A + ctx->B + ctx->counter++;
    ctx->A = ctx->B ^ (ctx->B >> RSHIFT);
    ctx->B = ctx->C + (ctx->C << LSHIFT);
    ctx->C = ((ctx->C << BARREL_SHIFT) | (ctx->C >> (16-BARREL_SHIFT))) + ctx->tmp;
    ctx->buffered = true;
    return ctx->tmp & 0xff;
}

/* ---------------------------------------------------------------------- */

static void usage(char *name) {
    fprintf(stderr,
            "%s: usage: %s algorithm length > filename\n"
            "\n"
            "\talgorithms:\n",
            name, name);
    for (int i=0; i<nalgorithms; i++)
        fprintf(stderr, "\t\t%d. %s\n", i, algorithms[i]);
    fprintf(stderr, "\n");
}

/* ---------------------------------------------------------------------- */

int main(int argc, char **argv) {
    void *ctx;
    uint8_t (*fnc)(void *ctx);

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

    switch (algo) {
    case 0:
        ctx = calloc(1, sizeof(struct random_single_eor_ctx));
        random_single_eor_seed(ctx, 0xff);
        fnc = (uint8_t (*)(void *ctx)) &random_single_eor;
        break;
    case 1:
        ctx = calloc(1, sizeof(struct random_four_taps_eor_ctx));
        random_four_taps_eor_seed(ctx, 0xff);
        fnc = (uint8_t (*)(void *ctx)) &random_four_taps_eor;
        break;
    case 2: {
        ctx = calloc(1, sizeof(struct random_sfc16_ctx));
        uint16_t seed[] = { 0xd33e, 0x607e, 0x834a, 0x517a };
        random_sfc16_seed(ctx, seed);
        fnc = (uint8_t (*)(void *ctx)) &random_sfc16;
        break;
        }
    default:
        fprintf(stderr, "%s: error: algorithm %s not implemented yet\n",
                                                argv[0], algorithms[algo]);
        return 1;
    }

    for (long long int i=0; i<length; i++) {
        putc(fnc(ctx), stdout);
    }

    return 0;
}

/* ---------------------------------------------------------------------- */

