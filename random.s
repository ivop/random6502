;
; PSEUDO RANDOM NUMBER GENERATOR(S)
;
; sfc16 and chacha20 Copyright (C) 2023 by Ivo van Poorten
; single_eor Copyright (C) ? by White Flame
; four_taps_eor Copyright (C) 2002 by Lee E. Davison
;
;               quality speed   code+data       ZP
; single_eor    0       5*****  17              1
; four_taps_eor 0       5*****  37              1
; sfc16         2**     4****   185             14
; chacha20(8)   3***    4****   2450            64
; chacha20(12)  4****   3***    2450            64
; chacha20(20)  5*****  2**     2450            64
;
; fill 4kB byte per byte, DMA off, VBI on for counter
;
; single_eor          7 frames (0.14s)
; four_taps_eor      11 frames (0.22s)
; sfc16              42 frames (0.84s)
; chacha20(8)        56 frames (1.12s)
; chacha20(12)       80 frames (1.60s)
; chacha20          127 frames (2.54s)

; -----------------------------------------------------------------------------

WHERE = *

; -----------------------------------------------------------------------------

; ZERO PAGE

    org $80

.ifdef RANDOM_ENABLE_CHACHA20
outbuf
outbuf0
    .ds 4
outbuf1
    .ds 4
outbuf2
    .ds 4
outbuf3
    .ds 4
outbuf4
    .ds 4
outbuf5
    .ds 4
outbuf6
    .ds 4
outbuf7
    .ds 4
outbuf8
    .ds 4
outbuf9
    .ds 4
outbuf10
    .ds 4
outbuf11
    .ds 4
outbuf12
    .ds 4
outbuf13
    .ds 4
outbuf14
    .ds 4
outbuf15
    .ds 4
.endif

.ifdef RANDOM_ENABLE_SFC16
xa
    .ds 2
xb
    .ds 2
xc
    .ds 2
sfc16_counter
    .ds 2
xb_rshift
xc_lshift
xc_barrel_lshift
    .ds 2
xc_barrel_rshift
    .ds 2
tmp
    .ds 2

.endif

.ifdef RANDOM_ENABLE_FOUR_TAPS_EOR
xor4seed
    .ds 1
.endif

.ifdef RANDOM_ENABLE_SINGLE_EOR
xor1seed
    .ds 1
.endif

; -----------------------------------------------------------------------------

    org WHERE

; -----------------------------------------------------------------------------

; Modified PRNG by White Flame, 0..255 exactly once, from codebase64.org
; NOTE: noticed a run like 1 2 4 8 $10 $20, not good

.ifdef RANDOM_ENABLE_SINGLE_EOR

RANDOM_START_SINGLE_EOR = *

.proc random_single_eor_seed
    sta xor1seed
    rts
.endp

.proc random_single_eor
    lda xor1seed
    beq doEor
    asl
    beq noEor ;if the input was $80, skip the EOR
    bcc noEor
doEor:
    eor #$1d
noEor:
    sta xor1seed
    rts
.endp

.print 'single_eor: ', RANDOM_START_SINGLE_EOR, '-', *-1, ' (', *-RANDOM_START_SINGLE_EOR, ')'

.endif

; -----------------------------------------------------------------------------

; Lee E. Davison, 8-bits, taps at 7,5,4,3
; https://philpem.me.uk/leeedavison/6502/prng/index.html
; NOTE: also has shifted runs

.ifdef RANDOM_ENABLE_FOUR_TAPS_EOR

RANDOM_START_FOUR_TAPS_EOR = *

.proc random_four_taps_eor_seed
    sta xor4seed
    rts
.endp

.proc random_four_taps_eor
    lda xor4seed
    and #%10111000  ; mask-out non feedback bits

    ldy #0
    .rept 5         ; need 5 to shift out all feedback bits
    asl
    bcc @+          ; bit clear
    iny             ; increment feedback counter
@
    .endr
    tya
    lsr
    lda xor4seed
    rol
    sta xor4seed
    rts
.endp

.print 'four_taps_eor: ', RANDOM_START_FOUR_TAPS_EOR, '-', *-1, ' (', *-RANDOM_START_FOUR_TAPS_EOR, ')'

.endif

; -----------------------------------------------------------------------------

; https://pracrand.sourceforge.net/RNG_engines.txt
;
;             quality speed  theory  size        notes                    bits
; efiix8x384  5*****  3***   0       388         -                           8
; efiix16x384 5*****  3***   0       776 bytes   -                          16
; efiix32x384 5*****  3***   0       1552 bytes  crypto                     32
; chacha(8)   5*****  1*     3***    124 bytes   crypto + random access     32
; hc256       5*****  2**    3***    8580 bytes  best quality, best crypto  32
;
;             quality speed  theory  size        notes                    bits
; sfc16       2**     5***** 0       8 bytes     fastest RNG & smallest RNG 16
; sfc32       3***    5***** 0       16 bytes    best speed                 32
; jsf32       3***    5***** 0       16 bytes    -                          32

; -----------------------------------------------------------------------------

; sfc16 is simple ;)
; quality is a lot higher than the eor ones, speed is acceptible
; without rept/endr it is slightly faster

.ifdef RANDOM_ENABLE_SFC16

RANDOM_START_SFC16 = *

BARREL_SHIFT=6
RSHIFT=5
LSHIFT=3

; AX = pointer to 8 bytes seed

.proc random_sfc16_seed
    sta seed+1
    stx seed

    ldx #7
@
    lda seed: $1234,x
    sta xa,x
    dex
    bpl @-
    rts
.endp

.proc random_sfc16
    lda buffered
    beq calculate_new

    dec buffered
    lda tmp+1
    rts

calculate_new
    ; tmp = a + b + counter++;
    adw xa xb tmp
    adw tmp sfc16_counter tmp
    inw sfc16_counter

    ; a = b ^ (b >> RSHIFT)
    mwa xb xb_rshift
    ldy #RSHIFT
@
    lsr xb_rshift+1
    ror xb_rshift
    dey
    bne @-
    lda xb
    eor xb_rshift
    sta xa
    lda xb+1
    eor xb_rshift+1
    sta xa+1

    ; b = c + (c << LSHIFT)
    mwa xc xc_lshift
    ldy #LSHIFT
@
    asl xc_lshift
    rol xc_lshift+1
    dey
    bne @-
    adw xc xc_lshift xb

    ; c = ((c << BARREL_SHIFT) | (c >> (16 - BARREL_SHIFT))) + tmp
    mwa xc xc_barrel_lshift
    mwa xc xc_barrel_rshift
    ldy #BARREL_SHIFT
@
    asl xc_barrel_lshift
    rol xc_barrel_lshift+1
    dey
    bne @-
    ldy #16-BARREL_SHIFT
@
    lsr xc_barrel_rshift+1
    ror xc_barrel_rshift
    dey
    bne @-
    lda xc_barrel_lshift
    ora xc_barrel_rshift
    sta xc
    lda xc_barrel_lshift+1
    ora xc_barrel_rshift+1
    sta xc+1
    adw xc tmp xc

    ; return tmp
    lda tmp
    inc buffered

    rts

buffered
    dta 0
.endp

.print 'sfc16: ', RANDOM_START_SFC16, '-', *-1, ' (', *-RANDOM_START_SFC16, ')'

.endif

; -----------------------------------------------------------------------------

; Chacha20
; https://en.wikipedia.org/wiki/Salsa20
; inspired by PractRand and OpenSSL

.ifdef RANDOM_ENABLE_CHACHA20

RANDOM_START_CHACHA20 = *

.macro inc64 loc
    clc
    lda :loc
    adc #1
    sta :loc
    .rept 7, #
    lda :loc+#
    adc #0
    sta :loc+#
    .endr
.endm

.macro add32 srcloc addloc dstloc
    clc
    .rept 4, #-1
    lda :srcloc+#
    adc :addloc+#
    sta :dstloc+#
    .endr
.endm

.macro xor32 srcloc xorloc dstloc
    .rept 4, #-1
    lda :srcloc+#
    eor :xorloc+#
    sta :dstloc+#
    .endr
.endm

.macro rol32 rolloc times
    ldx #:times
@
    asl :rolloc
    rol :rolloc+1
    rol :rolloc+2
    rol :rolloc+3
    lda :rolloc
    adc #0
    sta :rolloc
    dex
    bne @-
.endm

.macro rol32_16 loc
    lda :loc
    ldx :loc+1

    mvy :loc+2 :loc
    mvy :loc+3 :loc+1

    sta :loc+2
    stx :loc+3
.endm

.macro rol32_8 loc
    ldx :loc+3

    mva :loc+2 :loc+3
    mva :loc+1 :loc+2
    mva :loc+0 :loc+1

    stx :loc+0
.endm

.macro STEP one two three times
    add32 :one :two :one
    xor32 :three :one :three
.if :times=16
    rol32_16 :three
.elseif :times=8
    rol32_8 :three
.elseif :times=12
    rol32_8 :three
    rol32 :three 4
.else
    rol32 :three :times
.endif
.endm

.macro QUARTERROUND AAA BBB CCC DDD
    STEP outbuf:AAA outbuf:BBB outbuf:DDD 16
    STEP outbuf:CCC outbuf:DDD outbuf:BBB 12
    STEP outbuf:AAA outbuf:BBB outbuf:DDD 8
    STEP outbuf:CCC outbuf:DDD outbuf:BBB 7
.endm

.proc random_chacha20_core
    ldy #63
@
    mva state,y outbuf,y
    dey
    bpl @-

    lda rounds: #10
    sta rounds_counter

loop
    QUARTERROUND 0, 4, 8, 12
    QUARTERROUND 1, 5, 9, 13
    QUARTERROUND 2, 6, 10, 14
    QUARTERROUND 3, 7, 11, 15
    QUARTERROUND 0, 5, 10, 15
    QUARTERROUND 1, 6, 11, 12
    QUARTERROUND 2, 7, 8, 13
    QUARTERROUND 3, 4, 9, 14

    dec rounds_counter
    jne loop

; increase counter for next block

    inc64 state_counter
    rts

rounds_counter
    dta 0
.endp

.proc random_chacha20
    ldy position
    bpl @+

    jsr random_chacha20_core

    ldy #63
    sty position
@
    lda outbuf,y
    dec position

    rts

position
    dta 0
.endp

; AX = pointer to 12 dwords (48 bytes) seed, counter and nonce

.proc random_chacha20_seed
    sta seed+1
    stx seed

    ldx #47
@
    lda seed: $1234,x
    sta state+16,x
    dex
    bpl @-

    rts
.endp

state
constants
    dta "expand 32-byte k"
seeds
:8  .dword 0
state_counter
:2  .dword 0
nonce
:2  .dword 0

.print 'chacha20: ', RANDOM_START_CHACHA20, '-', *-1, ' (', *-RANDOM_START_CHACHA20, ')'

.endif

; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------

