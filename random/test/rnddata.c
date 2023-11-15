#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

/* ---------------------------------------------------------------------- */

static char *algorithms[] = {
    "single_eor",
    "four_taps_eor",
    "sfc16",
    "chacha20(8)",
    "chacha20(12)",
    "chacha20(20)",
    "jsf32"
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

static void random_sfc16_seed(struct random_sfc16_ctx *ctx, uint16_t *seed) {
    ctx->A = seed[0];
    ctx->B = seed[1];
    ctx->C = seed[2];
    ctx->counter = seed[3];
    // 8x16-bits discarded
    for (int i=0; i<16; i++) random_sfc16(ctx);
}

/* ---------------------------------------------------------------------- */

struct random_chacha20_ctx {
    uint32_t state[16], outbuf[16];
    int position, rounds;

};

static inline uint32_t pack32(const uint8_t a, const uint8_t b, const uint8_t c, const uint8_t d) {
    return a | (b<<8) | (c<<16) | (d<<24);
}

static void random_chacha20_seed(struct random_chacha20_ctx *ctx, uint32_t *seed, int rounds) {
    ctx->state[0] = pack32('e', 'x', 'p', 'a');
    ctx->state[1] = pack32('n', 'd', ' ', '3');
    ctx->state[2] = pack32('2', '-', 'b', 'y');
    ctx->state[3] = pack32('t', 'e', ' ', 'k');
    for (int i=0; i<12; i++) ctx->state[4+i] = seed[i];
    ctx->position = -1;
    ctx->rounds = rounds;
}

#define ROL32(v, r) ( ((v) << (r)) | ((v) >> (32-(r))) )

#define STEP(x, y, z, r) \
    buf[x] += buf[y]; \
    buf[z] ^= buf[x]; \
    buf[z] = ROL32(buf[z], r);

static inline void random_chacha20_quarter_round(uint32_t *buf, int a, int b, int c, int d) {
    STEP(a,b,d,16);
    STEP(c,d,b,12);
    STEP(a,b,d,8);
    STEP(c,d,b,7);
}

static void random_chacha20_core(struct random_chacha20_ctx *ctx) {
    memcpy(ctx->outbuf, ctx->state, sizeof(ctx->outbuf));

    for (int i=0; i<ctx->rounds; i+=2) {
        random_chacha20_quarter_round(ctx->outbuf, 0, 4,  8, 12);
        random_chacha20_quarter_round(ctx->outbuf, 1, 5,  9, 13);
        random_chacha20_quarter_round(ctx->outbuf, 2, 6, 10, 14);
        random_chacha20_quarter_round(ctx->outbuf, 3, 7, 11, 15);
        random_chacha20_quarter_round(ctx->outbuf, 0, 5, 10, 15);
        random_chacha20_quarter_round(ctx->outbuf, 1, 6, 11, 12);
        random_chacha20_quarter_round(ctx->outbuf, 2, 7,  8, 13);
        random_chacha20_quarter_round(ctx->outbuf, 3, 4,  9, 14);
    }

    ctx->state[12]++;
    if (!ctx->state[12]) ctx->state[13]++;
}

static uint8_t random_chacha20(struct random_chacha20_ctx *ctx) {
    if (ctx->position < 0) {
        random_chacha20_core(ctx);
        ctx->position = 63;
    }

    int w = ctx->position >> 2;
    int s = ctx->position & 3;
    ctx->position--;
    return (ctx->outbuf[w] & (0xff << (s*8))) >> (s*8);
}

/* ---------------------------------------------------------------------- */

struct random_jsf32_ctx {
    uint32_t a,b,c,d;
    int pos;
};

static void random_jsf32_core(struct random_jsf32_ctx *ctx) {
    uint32_t e = ctx->a - ROL32(ctx->b, 27);
    ctx->a = ctx->b ^ ROL32(ctx->c, 17);
    ctx->b = ctx->c + ctx->d;
    ctx->c = ctx->d + e;
    ctx->d =      e + ctx->a;
    // random number is d
}

static uint8_t random_jsf32(struct random_jsf32_ctx *ctx) {
    if (ctx->pos < 0) {
        random_jsf32_core(ctx);
        ctx->pos = 3;
    }

    int s = ctx->pos;
    ctx->pos--;
    return (ctx->d & (0xff << (s*8))) >> (s*8);
}

static void random_jsf32_seed(struct random_jsf32_ctx *ctx, uint64_t seed) {
    ctx->a = 0xf1ea5eed ^ (seed >> 32);
    ctx->b = seed;                      // truncated
    ctx->c = seed ^ (seed >> 32);       // truncated
    ctx->d = seed;                      // truncated
    ctx->pos = -1;
    for (int i=0; i<20; i++) random_jsf32_core(ctx);
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
    case 3: {
        ctx = calloc(1, sizeof(struct random_chacha20_ctx));
        uint32_t seed[] = {
            0x93ba769e, 0xcf1f833e, 0x06921c46, 0xf57871ac,
            0x363eca41, 0x766a5537, 0x04e7a5dc, 0xe385505b,
            0, 0,
            0x81a3749a, 0x7410533d
        };
        random_chacha20_seed(ctx, seed, 8);
        fnc = (uint8_t (*)(void *ctx)) &random_chacha20;
        break;
        }
    case 4: {
        ctx = calloc(1, sizeof(struct random_chacha20_ctx));
        uint32_t seed[] = {
            0x93ba769e, 0xcf1f833e, 0x06921c46, 0xf57871ac,
            0x363eca41, 0x766a5537, 0x04e7a5dc, 0xe385505b,
            0, 0,
            0x81a3749a, 0x7410533d
        };
        random_chacha20_seed(ctx, seed, 12);
        fnc = (uint8_t (*)(void *ctx)) &random_chacha20;
        break;
        }
    case 5: {
        ctx = calloc(1, sizeof(struct random_chacha20_ctx));
        uint32_t seed[] = {
            0x93ba769e, 0xcf1f833e, 0x06921c46, 0xf57871ac,
            0x363eca41, 0x766a5537, 0x04e7a5dc, 0xe385505b,
            0, 0,
            0x81a3749a, 0x7410533d
        };
        random_chacha20_seed(ctx, seed, 20);
        fnc = (uint8_t (*)(void *ctx)) &random_chacha20;
        break;
        }
    case 6: {
        ctx = calloc(1, sizeof(struct random_jsf32_ctx));
        random_jsf32_seed(ctx, 0xdeadbeefb01dface);
        fnc = (uint8_t (*)(void *ctx)) &random_jsf32;
        break;
        }
    default:
        fprintf(stderr, "%s: error: algorithm %d not implemented yet\n",
                                                            argv[0], algo);
        return 1;
    }

    for (long long int i=0; i<length; i++) {
        putc(fnc(ctx), stdout);
    }

    return 0;
}

/* ---------------------------------------------------------------------- */

