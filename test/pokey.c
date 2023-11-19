#include <stdio.h>
#include <stdint.h>
#include <string.h>

static uint8_t buffer[131071+8];

int main(int argc, char **argv) {
    uint32_t poly17 = 0;
    for(int i=0; i<131071; ++i) {
        poly17 = (poly17 >> 1) + (~((poly17 << 16) ^ (poly17 << 11)) & 0x10000);
        buffer[i] = (poly17 >> 8) & 1;
    }
    memcpy(buffer+131071, buffer, 8);
    int pos = 0;
    while (1) {
        uint8_t byte = 0;
        uint8_t *src = buffer+pos++;
        if (pos == 131071) pos=0;
        for (int i=7; i>=0; --i) byte = (byte+byte) + src[i];
        fputc(~byte,stdout);
    }
}
