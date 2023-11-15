
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

ptr = $1e       ; PBUFSZ/PTEMP, we can safely use it and leave 128 bytes
                ; free on ZP ($80-$ff)
                ; We also return the amount of frames passed here (big-endian)

.proc main
    mwa #$4000 ptr
    mva #0 $022f
    mva #0 $d400

    lda #$ff
    jsr random_single_eor_seed

    lda #$ff
    jsr random_four_taps_eor_seed

    lda #>sfc16_seed
    ldx #<sfc16_seed
    jsr random_sfc16_seed

    lda #>chacha20_seed
    ldx #<chacha20_seed
    jsr random_chacha20_seed

ROUNDS=20
    mva #ROUNDS/2 random_chacha20_core.rounds

@
    lda $d40b
    bne @-

    mwa #0 19

fill
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

sfc16_seed
    dta $3e, $d3, $7e, $60, $4a, $83, $7a, $51

chacha20_seed
    .dword 0x93ba769e                   ; seed0
    .dword 0xcf1f833e
    .dword 0x06921c46
    .dword 0xf57871ac
    .dword 0x363eca41
    .dword 0x766a5537
    .dword 0x04e7a5dc
    .dword 0xe385505b                   ; seed7
    .dword 0, 0                         ; counter
    .dword 0x81a3749a, 0x7410533d       ; nonce

    run main
