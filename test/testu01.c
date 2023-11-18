#include <stdio.h>
#include "TestU01.h"

static unsigned int from_stdin(void) {
    int a = getc(stdin);
    a |= getc(stdin) << 8;
    a |= getc(stdin) << 16;
    a |= getc(stdin) << 24;
    return a;
}

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

