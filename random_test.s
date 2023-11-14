
; speed test
;
; fill 4kB with random bytes, byte per byte
;
; PAL timing, 1 frame is 1/50th of a second
; screen off
; vbi on (for counter)
;
; results at the top of random.s

    org $1000

.define RANDOM_ENABLE_SINGLE_EOR
.define RANDOM_ENABLE_FOUR_TAPS_EOR
.define RANDOM_ENABLE_SFC16
.define RANDOM_ENABLE_CHACHA20

    icl 'random.s'

ptr = $f0

.proc main
    mwa #$4000 ptr
    mva #0 $022f
    mva #0 $d400

ROUNDS=20
    mva #ROUNDS/2 random_chacha20_core.rounds

@
    lda $d40b
    bne @-

    mwa #0 19

fill
;    jsr random_single_eor
;    jsr random_four_taps_eor
;    jsr random_sfc16
    jsr random_chacha20

    ldy #0
    sta (ptr),y
    sta $d01a

    inw ptr
    cpw ptr #$5000
    bne fill

    mwa 19 ptr          ; number of frames Big-Endian

    jmp *
.endp

    run main
