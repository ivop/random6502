
    org $1000

.define RANDOM_ENABLE_CHACHA20
    icl 'random.s'

ptr = $f0

.proc main
    mwa #$2000 ptr

fill
    jsr random_chacha20

    ldy #0
    sta (ptr),y
    sta $d01a

    inw ptr
    cpw ptr #$3000
    bne fill

    jmp *
.endp

    run main
