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
    "sfc32",
    "sha2"
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

struct random_sfc32_ctx {
    uint32_t a,b,c,counter,tmp;
    int8_t pos;
};

// {21,9,3}, {15,8,3} good sets
//      the last one is faster on the 6502, rol32(c,15)==ror32(c,17)
//      rshift32(b,8) is byte shuffling, remains lshift32(c,3)
static void random_sfc32_core(struct random_sfc32_ctx *ctx) {
    ctx->tmp = ctx->a + ctx->b + ctx->counter++;
    ctx->a = ctx->b ^ (ctx->b >> 8);
    ctx->b = ctx->c + (ctx->c << 3);
    ctx->c = ROL32(ctx->c,15) + ctx->tmp;
};

static uint8_t random_sfc32(struct random_sfc32_ctx *ctx) {
    if (ctx->pos < 0) {
        random_sfc32_core(ctx);
        ctx->pos = 3;
    }

    int s = ctx->pos;
    ctx->pos--;
    return (ctx->tmp & (0xff << (s*8))) >> (s*8);
};

static void random_sfc32_seed(struct random_sfc32_ctx *ctx, uint32_t *seed) {
    ctx->a = seed[0];
    ctx->b = seed[1];
    ctx->c = seed[2];
    ctx->counter = 1;
    ctx->pos = -1;
    for (int i=0; i<15; i++)
        random_sfc32_core(ctx);
};

/* ---------------------------------------------------------------------- */

// based on the SHA-2 algorithm
// https://en.wikipedia.org/wiki/SHA-2
// after each chunk, the hash is returned as random number
// when we run out of bytes, the current chunk is xor-ed with the hash
// at an increasing looping offset (0..8*wordsize) and handled as a new chunk
// roughly based on PractRands SHA2_pooling, except for the sliding input
// buffer. there is never a last chunk so all the message padding of SHA-2
// is ignored. note that if these functions are used for a proper SHA-2 digest
// you need to take care of the endianess of your input buffer and that of
// ctx->chunk.

#if 0

// SHA-256

#define SHA_WORD uint32_t
#define RORW(v, r) ( ((v) << (32-(r))) | ((v) >> (r)) )

#define KWSIZE 64

static SHA_WORD initial_hash[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

static SHA_WORD k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

#else

// SHA-512

#define SHA_WORD uint64_t
#define RORW(v, r) ( ((v) << (32-(r))) | ((v) >> (r)) )

#define KWSIZE 80

static SHA_WORD initial_hash[8] = {
0x6a09e667f3bcc908ull, 0xbb67ae8584caa73bull, 0x3c6ef372fe94f82bull, 0xa54ff53a5f1d36f1ull,
0x510e527fade682d1ull, 0x9b05688c2b3e6c1full, 0x1f83d9abfb41bd6bull, 0x5be0cd19137e2179ull
};

static SHA_WORD k[KWSIZE] = {
    0x428a2f98d728ae22ull, 0x7137449123ef65cdull, 0xb5c0fbcfec4d3b2full, 0xe9b5dba58189dbbcull, 0x3956c25bf348b538ull,
    0x59f111f1b605d019ull, 0x923f82a4af194f9bull, 0xab1c5ed5da6d8118ull, 0xd807aa98a3030242ull, 0x12835b0145706fbeull,
    0x243185be4ee4b28cull, 0x550c7dc3d5ffb4e2ull, 0x72be5d74f27b896full, 0x80deb1fe3b1696b1ull, 0x9bdc06a725c71235ull,
    0xc19bf174cf692694ull, 0xe49b69c19ef14ad2ull, 0xefbe4786384f25e3ull, 0x0fc19dc68b8cd5b5ull, 0x240ca1cc77ac9c65ull,
    0x2de92c6f592b0275ull, 0x4a7484aa6ea6e483ull, 0x5cb0a9dcbd41fbd4ull, 0x76f988da831153b5ull, 0x983e5152ee66dfabull,
    0xa831c66d2db43210ull, 0xb00327c898fb213full, 0xbf597fc7beef0ee4ull, 0xc6e00bf33da88fc2ull, 0xd5a79147930aa725ull,
    0x06ca6351e003826full, 0x142929670a0e6e70ull, 0x27b70a8546d22ffcull, 0x2e1b21385c26c926ull, 0x4d2c6dfc5ac42aedull,
    0x53380d139d95b3dfull, 0x650a73548baf63deull, 0x766a0abb3c77b2a8ull, 0x81c2c92e47edaee6ull, 0x92722c851482353bull,
    0xa2bfe8a14cf10364ull, 0xa81a664bbc423001ull, 0xc24b8b70d0f89791ull, 0xc76c51a30654be30ull, 0xd192e819d6ef5218ull,
    0xd69906245565a910ull, 0xf40e35855771202aull, 0x106aa07032bbd1b8ull, 0x19a4c116b8d2d0c8ull, 0x1e376c085141ab53ull,
    0x2748774cdf8eeb99ull, 0x34b0bcb5e19b48a8ull, 0x391c0cb3c5c95a63ull, 0x4ed8aa4ae3418acbull, 0x5b9cca4f7763e373ull,
    0x682e6ff3d6b2b8a3ull, 0x748f82ee5defb2fcull, 0x78a5636f43172f60ull, 0x84c87814a1f0ab72ull, 0x8cc702081a6439ecull,
    0x90befffa23631e28ull, 0xa4506cebde82bde9ull, 0xbef9a3f7b2c67915ull, 0xc67178f2e372532bull, 0xca273eceea26619cull,
    0xd186b8c721c0c207ull, 0xeada7dd6cde0eb1eull, 0xf57d4f7fee6ed178ull, 0x06f067aa72176fbaull, 0x0a637dc5a2c898a6ull,
    0x113f9804bef90daeull, 0x1b710b35131c471bull, 0x28db77f523047d84ull, 0x32caab7b40c72493ull, 0x3c9ebe0a15c9bebcull,
    0x431d67c49c100d4cull, 0x4cc5d4becb3e42b6ull, 0x597f299cfc657e2aull, 0x5fcb6fab3ad6faecull, 0x6c44198c4a475817ull
};

#endif

struct random_sha2_ctx {
    SHA_WORD h[8];
    SHA_WORD chunk[16];
    unsigned int phase;
    int pos;
};

static SHA_WORD w[KWSIZE];

static void random_sha2_handle_chunk(struct random_sha2_ctx *ctx) {
    memcpy(w, ctx->chunk, 16*sizeof(SHA_WORD));

    for (int i=16; i<KWSIZE; i++) {
        SHA_WORD s0 = RORW(w[i-15], 7) ^ RORW(w[i-15],18) ^ RORW(w[i-15], 3);
        SHA_WORD s1 = RORW(w[i- 2],17) ^ RORW(w[i- 2],19) ^ RORW(w[i- 2],10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }

    SHA_WORD a = ctx->h[0];
    SHA_WORD b = ctx->h[1];
    SHA_WORD c = ctx->h[2];
    SHA_WORD d = ctx->h[3];
    SHA_WORD e = ctx->h[4];
    SHA_WORD f = ctx->h[5];
    SHA_WORD g = ctx->h[6];
    SHA_WORD h = ctx->h[7];

    for (int i=0; i<KWSIZE; i++) {
        SHA_WORD S1 = RORW(e,6) ^ RORW(e,11) ^ RORW(e,25);
        SHA_WORD ch = (e & f) ^ ((~e) & g);
        SHA_WORD temp1 = h + S1 + ch + k[i] + w[i];
        SHA_WORD S0 = RORW(a,2) ^ RORW(a,13) ^ RORW(a,22);
        SHA_WORD maj = (a & b) ^ (a & c) ^ (b & c);
        SHA_WORD temp2 = S0 + maj;

        h = g;
        g = f;
        f = e;
        e = d + temp1;
        d = c;
        c = b;
        b = a;
        a = temp1 + temp2;
    }

    ctx->h[0] += a;
    ctx->h[1] += b;
    ctx->h[2] += c;
    ctx->h[3] += d;
    ctx->h[4] += e;
    ctx->h[5] += f;
    ctx->h[6] += g;
    ctx->h[7] += h;
}

static void random_sha2_core(struct random_sha2_ctx *ctx) {
    uint8_t *p = (uint8_t *) ctx->chunk;
    uint8_t *q = (uint8_t *) ctx->h;

    p += ctx->phase;

    for (unsigned int i = 0; i<8*sizeof(SHA_WORD); i++)
        *(p+i) ^= *(q+i);

    ctx->phase++;
    if (ctx->phase > 8*sizeof(SHA_WORD)) ctx->phase = 0;

    random_sha2_handle_chunk(ctx);
}

static uint8_t random_sha2(struct random_sha2_ctx *ctx) {
    if (ctx->pos < 0) {
        random_sha2_core(ctx);
        ctx->pos = 8*sizeof(SHA_WORD)-1;
    }

    int s = ctx->pos;
    ctx->pos--;
    uint8_t *p = (uint8_t *) ctx->h;
    return *(p+s);
}

static void random_sha2_seed(struct random_sha2_ctx *ctx, uint32_t seed) {
    memcpy(ctx->h, initial_hash, 8*sizeof(uint32_t));
    memset(ctx->chunk, 0, 16*sizeof(uint32_t));
    ctx->chunk[0] = seed;
    ctx->phase = 0;
    ctx->pos = -1;
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
        ctx = calloc(1, sizeof(struct random_sfc32_ctx));
        uint32_t seed[] = { 0xdeadbeef, 0xb01dface, 0xc0ffee13 };
        random_sfc32_seed(ctx, seed);
        fnc = (uint8_t (*)(void *ctx)) &random_sfc32;
        break;
        }
    case 9: {
        ctx = calloc(1, sizeof(struct random_sha2_ctx));
        random_sha2_seed(ctx, 0);
        fnc = (uint8_t (*)(void *ctx)) &random_sha2;
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

