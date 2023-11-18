; ----------------------------------------------------------------------------
;
; speed test
;
; fill 4kB with random bytes, byte per byte
;
; PAL timing, 1 frame is 1/50th of a second
; screen off
; vbi on (for counter)
;
; results at the top of random.s
;
; ----------------------------------------------------------------------------

    org $2000

; ----------------------------------------------------------------------------

.ifdef TEST_BATCH1
.define RANDOM_ENABLE_SINGLE_EOR
.define RANDOM_ENABLE_FOUR_TAPS_EOR
.define RANDOM_ENABLE_SFC16
.define RANDOM_ENABLE_CHACHA20
.define RANDOM_ENABLE_JSF32
.endif
.ifdef TEST_BATCH2
.define RANDOM_ENABLE_ARBEE
.endif

RANDOM_ZERO_PAGE = $80

    icl 'random.s'
    icl 'cio.s'

; ----------------------------------------------------------------------------

ptr = $1e       ; PBUFSZ/PTEMP, we can safely use it and leave 128 bytes
                ; free on ZP ($80-$ff)
                ; We also return the amount of frames passed here (big-endian)

; ----------------------------------------------------------------------------

.proc test_prng
    lda ptr+1
    clc
    adc #$10
    sta msb_end

    mva $022f save_dma
    mva #0 $022f
    mva #0 $d400

@
    lda $d40b
    bne @-

    mwa #0 19

fill
    jsr routine: $1234

    ldy #0
    sta (ptr),y
    sta $d01a

    inw ptr
    lda ptr+1
    cmp msb_end: #$12
    bne fill

    mwa 19 ptr          ; number of frames Big-Endian

    lda save_dma: #0
    sta $022f
    rts
.endp

; ----------------------------------------------------------------------------

.proc main

.ifdef TEST_BATCH1

    printsn 0, "single_eor:    "

    lda #$ff
    jsr random_single_eor_seed

    mwa #random_single_eor test_prng.routine
    mwa #$4000 ptr
    jsr test_prng

    jsr print_number

; --------

    printsn 0, "four_taps_eor: "

    lda #$ff
    jsr random_four_taps_eor_seed

    mwa #random_four_taps_eor test_prng.routine
    mwa #$5000 ptr
    jsr test_prng

    jsr print_number

; --------

    printsn 0, "sfc16:         "

    ldx #>sfc16_seed
    lda #<sfc16_seed
    jsr random_sfc16_seed

    mwa #random_sfc16 test_prng.routine
    mwa #$6000 ptr
    jsr test_prng

    jsr print_number

; --------

    printsn 0, "chacha20(8):   "

    ldx #>chacha20_seed
    lda #<chacha20_seed
    jsr random_chacha20_seed

    mva #8/2 random_chacha20_core.rounds
    mwa #random_chacha20 test_prng.routine
    mwa #$7000 ptr
    jsr test_prng

    jsr print_number

; --------

    printsn 0, "chacha20(12):  "

    ldx #>chacha20_seed
    lda #<chacha20_seed
    jsr random_chacha20_seed

    mva #12/2 random_chacha20_core.rounds
    mwa #random_chacha20 test_prng.routine
    mwa #$8000 ptr
    jsr test_prng

    jsr print_number

; --------

    printsn 0, "chacha20(20):  "

    ldx #>chacha20_seed
    lda #<chacha20_seed
    jsr random_chacha20_seed

    mva #20/2 random_chacha20_core.rounds
    mwa #random_chacha20 test_prng.routine
    mwa #$9000 ptr
    jsr test_prng

    jsr print_number

; --------

    printsn 0, "jsf32:         "

    ldx #>jsf32_seed
    lda #<jsf32_seed
    jsr random_jsf32_seed

    mwa #random_jsf32 test_prng.routine
    mwa #$a000 ptr
    jsr test_prng

    jsr print_number

.endif

; --------

.ifdef TEST_BATCH2

    printsn 0, "arbee:         "

    ldx #>arbee_seed
    lda #<arbee_seed
    jsr random_arbee_seed

    mwa #random_arbee test_prng.routine
    mwa #$4000 ptr
    jsr test_prng

    jsr print_number

.endif

    jmp *
.endp

; ----------------------------------------------------------------------------

; (ptr) points to a BIG-Endian number (!)

.proc print_number
    lda #' '
    sta pad
    sta buf

    ldy #8
repeat
    ldx #$ff
    sec

repeat2
    lda ptr+1
    sbc dec_table+0,y
    sta ptr+1
    lda ptr
    sbc dec_table+1,y
    sta ptr
    inx
    bcs repeat2

    lda ptr+1
    adc dec_table+0,y
    sta ptr+1
    lda ptr
    adc dec_table+1,y
    sta ptr

    tya
    pha
    txa
    pha

    bne not_zero

    lda pad
    beq skip
    bne justprint

not_zero
    ldx #'0'
    stx pad
    ora #'0'
    sta buf

justprint
    bput 0, 1, buf

skip
    pla
    tax
    pla
    tay

    dey
    dey
    bpl repeat

    bput 0, 1, eolbuf

    rts
.endp

; ----------------------------------------------------------------------------

sfc16_seed
    dta $3e, $d3, $7e, $60, $4a, $83, $7a, $51

; ----------------------------------------------------------------------------

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

; ----------------------------------------------------------------------------

jsf32_seed
    .dword 0xb01dface, 0xdeadbeef

; ----------------------------------------------------------------------------

arbee_seed
    .byte 1,0,0,0, 0,0,0,0
    .byte 1,0,0,0, 0,0,0,0
    .byte 1,0,0,0, 0,0,0,0
    .byte 1,0,0,0, 0,0,0,0

; ----------------------------------------------------------------------------

dec_table
    .word 1, 10, 100, 1000, 10000
pad
    dta ' '
buf
    dta '0'
eolbuf
    dta EOL

; ----------------------------------------------------------------------------

    run main
