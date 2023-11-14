;
; PSEUDO RANDOM NUMBER GENERATOR(S)
;
; sfc16 and chacha20 Copyright (C) 2023 by Ivo van Poorten
; single_eor Copyright (C) ? by White Flame
; four_taps_eor Copyright (C) 2002 by Lee E. Davison
;
;               quality speed   code+data size
; single_eor    0       5*****  11
; four_taps_eor 0       5*****  26
; sfc16         2**     4****   246
; chacha20(8)   3***    4****   3568
; chacha20(12)  4****   3***    3568
; chacha20(20)  5*****  2**     3568
;
; fill 4kB byte per byte, DMA off, VBI on for counter
;
; single_eor          7 frames (0.14s)
; four_taps_eor      11 frames (0.22s)
; sfc16              48 frames (0.96)
; chacha20(8)        68 frames (1.36s)
; chacha20(12)       98 frames (2.96s)
; chacha20          157 frames (3.14s)

; -----------------------------------------------------------------------------

; Modified PRNG by White Flame, 0..255 exactly once, from codebase64.org
; NOTE: noticed a run like 1 2 4 8 $10 $20, not good

.ifdef RANDOM_ENABLE_SINGLE_EOR

RANDOM_START_SINGLE_EOR = *

.proc random_single_eor
    lda seed
    beq doEor
    asl
    beq noEor ;if the input was $80, skip the EOR
    bcc noEor
doEor:
    eor #$1d
noEor:
    sta seed
    rts

seed
    dta $ff
.endp

.print 'single_eor: ', RANDOM_START_SINGLE_EOR, '-', *-1, ' (', *-RANDOM_START_SINGLE_EOR, ')'

.endif

; -----------------------------------------------------------------------------

; Lee E. Davison, 8-bits, taps at 7,5,4,3
; https://philpem.me.uk/leeedavison/6502/prng/index.html
; NOTE: also has shifted runs

.ifdef RANDOM_ENABLE_FOUR_TAPS_EOR

RANDOM_START_FOUR_TAPS_EOR = *

.proc random_four_taps_eor
    lda seed
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
    lda seed
    rol
    sta seed
    rts

seed
    dta $ff
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

.proc random_sfc16
    lda buffered
    beq calculate_new

    dec buffered
    lda tmp+1
    rts

calculate_new
    ; tmp = a + b + counter++;
    adw xa xb tmp
    adw tmp counter tmp
    inw counter

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

; size if $e0 bytes ($144 with rept/endr) which is quite a lot for
; deterministic behaviour (instead of using RANDOM)
;
; NOTE: include noise.dat from disk, see data.s

; seeded from /dev/urandom
seed64      ; auto seeded to a,b,c and counter
xa
    dta $3e, $d3
xb
    dta $7e, $60
xc
    dta $4a, $83
counter
    dta $7a, $51

xb_rshift
xc_lshift
xc_barrel_lshift
    dta 0, 0
xc_barrel_rshift
    dta 0, 0
tmp
    dta 0, 0
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

.macro add64 srcloc addloc dstloc
    clc
    .rept 8, #-1
    lda :srcloc+#
    adc :addloc+#
    sta :dstloc+#
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

    add64 counter0 one counter0
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

outbuf
outbuf0
    .dword 0
outbuf1
    .dword 0
outbuf2
    .dword 0
outbuf3
    .dword 0
outbuf4
    .dword 0
outbuf5
    .dword 0
outbuf6
    .dword 0
outbuf7
    .dword 0
outbuf8
    .dword 0
outbuf9
    .dword 0
outbuf10
    .dword 0
outbuf11
    .dword 0
outbuf12
    .dword 0
outbuf13
    .dword 0
outbuf14
    .dword 0
outbuf15
    .dword 0

state
state0
constant0
    dta "expa"
state1
constant1
    dta "nd 3"
state2
constant2
    dta "2-by"
state3
constant3
    dta "te k"
state4
seed0
    .dword 0x93ba769e
state5
seed1
    .dword 0xcf1f833e
state6
seed2
    .dword 0x06921c46
state7
seed3
    .dword 0xf57871ac
state8
seed4
    .dword 0x363eca41
state9
seed5
    .dword 0x766a5537
state10
seed6
    .dword 0x04e7a5dc
state11
seed7
    .dword 0xe385505b
state12
counter0
    .dword 0
state13
counter1
    .dword 0
state14
nonce0
    .dword 0x81a3749a
state15
nonce1
    .dword 0x7410533d

one
    .dword 1,0

.print 'chacha20: ', RANDOM_START_CHACHA20, '-', *-1, ' (', *-RANDOM_START_CHACHA20, ')'

.endif

; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------

