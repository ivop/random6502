#include <stdio.h>
#include "TestU01.h"

static const unsigned char reverse[256] = {
#   define R2(n)     n,     n + 2*64,     n + 1*64,     n + 3*64
#   define R4(n) R2(n), R2(n + 2*16), R2(n + 1*16), R2(n + 3*16)
#   define R6(n) R4(n), R4(n + 2*4 ), R4(n + 1*4 ), R4(n + 3*4 )
    R6(0), R6(2), R6(1), R6(3)
};

#if 1
static unsigned int from_stdin(void) {
    int a = reverse[getc(stdin)] << 24;
    a |= reverse[getc(stdin)] << 16;
    a |= reverse[getc(stdin)] << 8;
    a |= reverse[getc(stdin)];
    return a;
}
#else
static unsigned int from_stdin(void) {
    int a = getc(stdin);
    a |= getc(stdin) << 8;
    a |= getc(stdin) << 16;
    a |= getc(stdin) << 24;
    return a;
}
#endif

int main (void) {
    unif01_Gen* gen = unif01_CreateExternGenBits("stdin", from_stdin);

//    bbattery_Alphabit(gen, 100*1024*1024.0, 0, 32);
//    bbattery_Rabbit(gen, 100*1024*1024.0);
//    bbattery_FIPS_140_2(gen);
//    bbattery_SmallCrush(gen);
    bbattery_Crush(gen);
//    bbattery_BigCrush(gen);

    return 0;
}

