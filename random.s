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
; see: https://pracrand.sourceforge.net/RNG_engines.txt for more details
;

; -----------------------------------------------------------------------------

WHERE = *

    icl 'macros.s'

; -----------------------------------------------------------------------------

; ZERO PAGE

    org RANDOM_ZERO_PAGE

ZP_START = *

.ifdef RANDOM_ENABLE_SFC32
x32 .ds 4
y32 .ds 4
z32 .ds 4
t32 .ds 4
sfc32_counter .ds 4
.endif

.ifdef RANDOM_ENABLE_ARBEE
a64 .ds 8
b64 .ds 8
c64 .ds 8
d64 .ds 8
i64 .ds 8
e64 .ds 8
f64 .ds 8
.endif

.ifdef RANDOM_ENABLE_JSF32
a32 .ds 4
b32 .ds 4
c32 .ds 4
d32 .ds 4
e32 .ds 4
.endif

.ifdef RANDOM_ENABLE_CHACHA20
outbuf
outbuf0 .ds 4
outbuf1 .ds 4
outbuf2 .ds 4
outbuf3 .ds 4
outbuf4 .ds 4
outbuf5 .ds 4
outbuf6 .ds 4
outbuf7 .ds 4
outbuf8 .ds 4
outbuf9 .ds 4
outbuf10 .ds 4
outbuf11 .ds 4
outbuf12 .ds 4
outbuf13 .ds 4
outbuf14 .ds 4
outbuf15 .ds 4
.endif

.ifdef RANDOM_ENABLE_SFC16
xa .ds 2
xb .ds 2
xc .ds 2
sfc16_counter .ds 2
tmp .ds 2
.endif

.ifdef RANDOM_ENABLE_FOUR_TAPS_EOR
xor4seed .ds 1
.endif

.ifdef RANDOM_ENABLE_SINGLE_EOR
xor1seed .ds 1
.endif

.print 'ZP: ', ZP_START, '-', *-1, ' (', *-ZP_START, ')'

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
    stx seed+1
    sta seed

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

    mva #0 random_sfc16.buffered

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

    ; a = b ^ (b >> 5)
    lda xb+1
    lsr
    sta xa+1
    lda xb
    ror
    .rept 4
    lsr xa+1
    ror
    .endr
    eor xb
    sta xa
    lda xa+1
    eor xb+1
    sta xa+1

    ; b = c + (c << 3)
    lda xc
    sta xb
    lda xc+1

    .rept 3
    asl xb
    rol
    .endr

    sta xb+1

    lda xc
    clc
    adc xb
    sta xb
    lda xc+1
    adc xb+1
    sta xb+1

    ; c = ((c << 6) | (c >> (10))) + tmp
    ; equals
    ; c = ror16(c,10) + tmp         ;; 10 = 8 (byte swap) + 2

    lda xc
    ldx xc+1
    stx xc

    .rept 2,#
    lsr
    ror xc
    bcc skip:1
    ora #$80
skip:1
    .endr

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
.elseif :times=7
    rol32_8 :three
    ror32_1 :three
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
    stx seed+1
    sta seed

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
    ; e = a - rol32(b,27) = a - ror32(b,5)
    movror32_8 b32 e32
    rol32 e32 3
    sub32 a32 e32 e32

    ; a = b ^ rol32(c,17)
    movrol32_17_xor c32 b32 a32

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
    stx seedloc+1
    sta seedloc

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
; ***** ARBEE *****
; -----------------------------------------------------------------------------

.ifdef RANDOM_ENABLE_ARBEE

RANDOM_START_ARBEE = *

.proc random_arbee_core
    ; f = rol64(b, 45) = ror64(b, 19)
    movror64_16 b64 f64
    ror64 f64 3

    ; e = a + f
    add64 a64 f64 e64

    ; f = rol64(c,13)
    movrol64_16 c64 f64
    ror64 f64 3

    ; a = b ^ f
    eor64 b64 f64 a64

    ; f = rol64(d,37) = ror64(d,27)
    movror64_24 d64 f64
    ror64 f64 3

    ; b = c + f
    add64 c64 f64 b64

    ; c = e + d + i
    add64 e64 d64 c64
    add64 c64 i64 c64

    ; d = e + a
    add64 e64 a64 d64

    ; i++
    inc64 i64
    rts
.endp

.proc random_arbee
    ldy pos
    bpl @+

    jsr random_arbee_core

    ldy #7
    sty pos
@
    lda d64,y
    dec pos

    rts

pos
    dta -1
.endp

.proc random_arbee_mix
    mva #12 mixcnt

@
    jsr random_arbee_core

    dec mixcnt
    bne @-

    rts

mixcnt
    dta 0
.endp

.proc random_arbee_seed
    stx seedloc+1
    sta seedloc

    ldx #31
@
    lda seedloc: $1234,x
    sta a64,x
    dex
    bpl @-

    ldx #7
    lda #0
@
    sta i64,x
    dex
    bpl @-
    mva #1 i64

    mva #$ff random_arbee.pos

    jsr random_arbee_mix

    rts
.endp

.ifdef RANDOM_ENABLE_ARBEE_ENTROPY_POOLING

// AX points to uint64_t

.proc random_arbee_add_entropy
    stx entloc+1
    sta entloc

; save value and set d ^= value;
    ldx #7
@
    lda entloc: $1234,x
    sta value,x
    eor d64,x
    sta d64,x
    dex
    bpl @-

    mva #0 skip

looponce
    add64 b64 value b64

    lda skip: #0
    bne done

:4  jsr random_arbee_core

    inc skip
    jmp looponce

done
    rts

value
    .dword 0, 0
.endp

.endif

.print 'arbee: ', RANDOM_START_ARBEE, '-', *-1, ' (', *-RANDOM_START_ARBEE, ')'

.endif

; -----------------------------------------------------------------------------
; ***** SFC32 *****
; -----------------------------------------------------------------------------

.ifdef RANDOM_ENABLE_SFC32

RANDOM_START_SFC32 = *

.proc random_sfc32_core
    ; tmp = x + y + counter++
    add32 x32 y32 t32
    add32 t32 sfc32_counter t32
    inc32 sfc32_counter

    ; x = y ^ (y>>8)
    movlsr32_8_xor y32 y32 x32

    ; y = z + (z<<3)
    mov32 z32 y32
    asl32 y32 3
    add32 y32 z32 y32

    ; z = rol32(z,15) + tmp
    rol32_16 z32
    ror32_1 z32
    add32 z32 t32 z32

    rts
.endp

.proc random_sfc32
    ldy pos
    bpl @+

    jsr random_sfc32_core

    ldy #3
    sty pos
@
    lda t32,y
    dec pos

    rts

pos
    dta -1
.endp

.proc random_sfc32_seed
    stx seedloc+1
    sta seedloc

    ldx #11
@
    lda seedloc: $1234,x
    sta x32,x
    dex
    bpl @-

    mva #1 sfc32_counter
    lda #0
    sta sfc32_counter+1
    sta sfc32_counter+2
    sta sfc32_counter+3

    ldx #14
@
    stx savex

    jsr random_sfc32_core

    ldx savex: #0
    dex
    bpl @-

    mva #$ff random_sfc32.pos

    rts
.endp

.print 'sfc32: ', RANDOM_START_SFC32, '-', *-1, ' (', *-RANDOM_START_SFC32, ')'

.endif

; -----------------------------------------------------------------------------
