
; speed test
;
; fill 4kB with random bytes, byte per byte
;
; PAL timing, 1 frame is 1/50th of a second
; screen off
; vbi on (for counter)
;
; single_eor          7 frames (0.14s)
; four_taps_eor      11 frames (0.22s)
; sfc16              87 frames (1.74s)
; chacha20(8)       142 frames (2.84s)
; chacha20(12)      209 frames (4.18s)
; chacha20(20)      342 frames (6.84s)

    org $1000

.define RANDOM_ENABLE_SINGLE_EOR
.define RANDOM_ENABLE_FOUR_TAPS_EOR
.define RANDOM_ENABLE_SFC16
.define RANDOM_ENABLE_CHACHA20

    icl 'random.s'

ptr = $f0

.proc main
    mwa #$2000 ptr
    mva #0 $022f
    mva #0 $d400

ROUNDS=8

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
    cpw ptr #$3000
    bne fill

    mwa 19 ptr          ; number of frames Big-Endian

    jmp *
.endp

    run main
