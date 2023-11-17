;
; PSEUDO RANDOM NUMBER GENERATORS
;
; 6502 implementations of sfc16, chacha20, and jsf32:
; Copyright (C) 2023 by Ivo van Poorten
;
; sfc16, chacha20, and jsf32 based on C++ code by Chris Doty-Humphrey
; jsf32's C++ code is mostly by Robert Jenkins
; both are public domain
; https://pracrand.sourceforge.net/
;
; single_eor Copyright (C) ? by White Flame (codebase64.org)
; four_taps_eor Copyright (C) 2002 by Lee E. Davison
; https://philpem.me.uk/leeedavison/6502/prng/index.html
;
;               quality speed   code+data       ZP
; single_eor    0       5*****  17              1
; four_taps_eor 0       5*****  37              1
; sfc16         2**     4****   226             12
; chacha20(8)   4****   3***    2455            64
; chacha20(12)  5*****  2**     2455            64
; chacha20(20)  5*****  1*      2455            64
; jsf32         3***    4****   392             24
;
; fill 4kB byte per byte, DMA off, VBI on for counter
;
; single_eor          7 frames (0.14s)
; four_taps_eor      11 frames (0.22s)
; sfc16              27 frames (0.54s)
; chacha20(8)        56 frames (1.12s)
; chacha20(12)       88 frames (1.76s)
; chacha20(20)      127 frames (2.54s)
; jsf32              21 frames (0.42s)
;
; see: https://pracrand.sourceforge.net/RNG_engines.txt for more details
;
; TODO?
;
; hc256       5*****  2**    3***    8580 bytes  best quality, best crypto  32
; sfc32       3***    5***** 0       16 bytes    best speed                 32

; -----------------------------------------------------------------------------

WHERE = *

    icl 'macros.s'

; -----------------------------------------------------------------------------

; ZERO PAGE

    org $80

.ifdef RANDOM_ENABLE_JSF32
a32
    .ds 4
b32
    .ds 4
c32
    .ds 4
d32
    .ds 4
e32
    .ds 4
f32
    .ds 4
.endif

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
; *** SIMPLE EOR ****
; -----------------------------------------------------------------------------

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
; *** FOUR_TAPS_EOR ***
; -----------------------------------------------------------------------------

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
; **** SFC16 ****
; -----------------------------------------------------------------------------

.ifdef RANDOM_ENABLE_SFC16

RANDOM_START_SFC16 = *

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

    ldx #15             ; discard 8x16 bits
@
    stx savex
    jsr random_sfc16
    ldx savex: #0
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
    .rept 5
    lsr xb_rshift+1
    ror xb_rshift
    .endr

    lda xb
    eor xb_rshift
    sta xa
    lda xb+1
    eor xb_rshift+1
    sta xa+1

    ; b = c + (c << LSHIFT)
    mwa xc xc_lshift
    .rept 3
    asl xc_lshift
    rol xc_lshift+1
    .endr

    adw xc xc_lshift xb

    ; c = ((c << BARREL_SHIFT) | (c >> (16 - BARREL_SHIFT))) + tmp
    ; equals
    ; c = rol16(c,BARREL_SHIFT) + tmp

    .rept 6
    asl xc
    rol xc+1
    lda xc
    adc #0
    sta xc
    .endr

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
; ***** CHACHA20 *****
; -----------------------------------------------------------------------------

.ifdef RANDOM_ENABLE_CHACHA20

RANDOM_START_CHACHA20 = *

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

    mva #$ff random_chacha20.position
    rts
.endp

state
constants
    dta 'expand 32-byte k'
seeds
:8  .dword 0
state_counter
:2  .dword 0
nonce
:2  .dword 0

.print 'chacha20: ', RANDOM_START_CHACHA20, '-', *-1, ' (', *-RANDOM_START_CHACHA20, ')'

.endif

; -----------------------------------------------------------------------------
; ***** JSF32 *****
; -----------------------------------------------------------------------------

.ifdef RANDOM_ENABLE_JSF32

RANDOM_START_JSF32 = *

.proc random_jsf32_core
    ; e = a - rol32(b,27);
    mwa b32 e32
    mwa b32+2 e32+2
    ror32_8 e32
    rol32 e32 3
    sub32 a32 e32 e32

    ; f = rol32(c,17)
    mwa c32 f32
    mwa c32+2 f32+2
    rol32_16 f32
    rol32 f32 1

    ; a = b ^ f
    xor32 b32 f32 a32

    ; b = c + d
    add32 c32 d32 b32

    ; c = d + e
    add32 d32 e32 c32

    ; d = e + a
    add32 e32 a32 d32

    rts
.endp

.proc random_jsf32
    ldy pos
    bpl @+

    jsr random_jsf32_core

    ldy #3
    sty pos
@
    lda d32,y
    dec pos

    rts

pos
    dta -1
.endp

; pointer to uint64_t in XA

.proc random_jsf32_seed
    sta seedloc+1
    stx seedloc

    ldx #7
@
    lda seedloc: $1234,x
    sta seed,x
    dex
    bpl @-

    mwa #$5eed a32
    mwa #$f1ea a32+2

    xor32 a32 seed+4 a32

    .rept 4, #-1
    lda seed+#
    sta b32+#
    sta d32+#
    .endr

    xor32 b32 seed+4 c32

    ldx #19
@
    stx savex

    jsr random_jsf32_core

    ldx savex: #0
    dex
    bpl @-

    mva #$ff random_jsf32.pos
    rts

seed
    .dword 0, 0
.endp

.print 'jsf32: ', RANDOM_START_JSF32, '-', *-1, ' (', *-RANDOM_START_JSF32, ')'

.endif

; -----------------------------------------------------------------------------
