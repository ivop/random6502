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

