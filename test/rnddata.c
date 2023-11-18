#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>

/* ---------------------------------------------------------------------- */

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

// seed --> uint16_t [4]

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

// seed --> uint32_t [12]

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

#define ROL64(v, r) ( ((v) << (r)) | ((v) >> (64-(r))) )

struct random_arbee_ctx {
    uint64_t a, b, c, d, i;
    int pos;
};

static void random_arbee_core(struct random_arbee_ctx *ctx) {
    uint64_t f = ROL64(ctx->b, 45);
    uint64_t e = ctx->a + f;

    f = ROL64(ctx->c, 13);
    ctx->a = ctx->b ^ f;

    f = ROL64(ctx->d, 37);
    ctx->b = ctx->c + f;

    ctx->c = e + ctx->d;
    ctx->c = ctx->c + ctx->i;
    ctx->d = e + ctx->a;
    ctx->i++;
}

static uint8_t random_arbee(struct random_arbee_ctx *ctx) {
    if (ctx->pos < 0) {
        random_arbee_core(ctx);
        ctx->pos = 7;
    }

    int s = ctx->pos;
    ctx->pos--;
    return (ctx->d & (0xffull << (s*8))) >> (s*8);
}

static void random_arbee_mix(struct random_arbee_ctx *ctx) {
    for (int i=0; i<12; i++) random_arbee_core(ctx);
}

// seed --> uint64_t [4]

static void random_arbee_seed(struct random_arbee_ctx *ctx, uint64_t *seed) {
    ctx->a = seed[0];
    ctx->b = seed[1];
    ctx->c = seed[2];
    ctx->d = seed[3];
    ctx->i = 1;
    ctx->pos = -1;
    random_arbee_mix(ctx);
}

/* ---------------------------------------------------------------------- */

struct random_arbee8_ctx {
    uint8_t a, b, c, d, i, j, k, l;
};

//      e = a - ror(b,x)
//      a = b ^ ror(c,y)
//      b = c + d
//      c = d + e
//      d = e + a
//
// jsf64:
//      x=25, y=53      -->         64/4+9, 64/2+21 ???
// jsf32:
//      x=5, y=15       -->         32/4-(32/8-1), 32/2-1
//      x=5, y=15       -->         32/4-3, 32/2-1
// jsf16:
//      x=3, y=7        -->         16/4-(16/8-1), 16/2-1)
//      x=3, y=7        -->         16/4-1, 16/2-1)
//
// jsfX                 -->         X/4-(X/8)-1, X/2-1
//
// jsf8:
//      8/4-1, 8/2-1    -->         x=1, y=3
//
// arbee adds counter: c = d+e+i
// 8-bit counter suspicious at 16GB (FPF-14+6/16:all)
//               fails at 32Gb (FPF-14+6/16:all)
// 2x 8-bit counter?
// 4x 8-bit counter?
// 4x 8-bit counter and spread over a..d ?

static uint8_t random_arbee8(struct random_arbee8_ctx *ctx) {
    // if we use two LUTs, the rotates are lookups (512 bytes)
    // page align LUTs to avoid page crossing (+1 cycle per lookup)
    // no LUTs, ror 1 is easy, ror 3 is tricky with the high bit, perhaps rol 5?
    uint8_t e = ctx->a - ((ctx->b << 7) | (ctx->b >> 1));
    ctx->a = (ctx->b ^ ((ctx->c << 5) | (ctx->c >> 3))) + ctx->k;
    ctx->b = ctx->c + ctx->d + ctx->l;      // two CLCs
    ctx->c = ctx->d + e + ctx->i;           // two CLCs
    ctx->d = e + ctx->a + ctx->j;           // two CLCs
    ctx->i++;                               // inc32 i
    if (!ctx->i) {
        ctx->j++;
        if (!ctx->j) {
            ctx->k++;
            if (!ctx->k)
                ctx->l++;
        }
    }
    return ctx->d;
};

static void random_arbee8_seed(struct random_arbee8_ctx *ctx, uint32_t seed) {
    ctx->a = (seed >>  0) & 0xff;
    ctx->b = (seed >>  8) & 0xff;
    ctx->c = (seed >> 16) & 0xff;
    ctx->d = (seed >> 24) & 0xff;
    ctx->i = 1;
    ctx->j = ctx->k = ctx->l = 0;
    for (int i=0; i<20; i++) random_arbee8(ctx);
};

/* ---------------------------------------------------------------------- */

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
    case 7: {
        ctx = calloc(1, sizeof(struct random_arbee_ctx));
        uint64_t seed[] = { 1, 1, 1, 1 };
        random_arbee_seed(ctx, seed);
        struct random_arbee_ctx *p = ctx;
        if (p->a != 0x89048ccb2d89b1d8ull ||
            p->b != 0x93194005e4b240d8ull ||
            p->c != 0xea0d42647afb25a5ull ||
            p->d != 0x4594a972b9964399ull ||
            p->i != 13) {
            fprintf(stderr, "%s: error: arbee seeding failed\n", argv[0]);
            return 1;
        }
        fnc = (uint8_t (*)(void *ctx)) &random_arbee;
        break;
        }
    case 8: {
        ctx = calloc(1, sizeof(struct random_arbee8_ctx));
        random_arbee8_seed(ctx, 0xdeadbeef);
        fnc = (uint8_t (*)(void *ctx)) &random_arbee8;
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

