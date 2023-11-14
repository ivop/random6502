
RANDOM_START = *

; (modified PRNG by White Flame, 0..255 exactly once)
;    txa         ; seed is 0
;prng
;    beq doEor
;    asl
;    beq noEor ;if the input was $80, skip the EOR
;    bcc noEor
;doEor:
;    eor #$1d
;noEor:
;    sta waveform10,x
;    inx
;    bne prng

;
; NOTE: noticed a run like 1 2 4 8 $10 $20, not good

; Lee E. Davison, 8-bits, taps at 7,5,4,3
;    lda seed
;    and #%10111000  ; mask-out non feedback bits
;
;    ldy #0
;    .rept 5         ; need 5 to shift out all feedback bits
;    asl
;    bcc @+          ; bit clear
;    iny             ; increment feedback counter
;@
;    .endr
;    tya
;    lsr
;    lda seed
;    rol
;    sta seed
;    sta waveform10,x
;
; NOTE: random enough?

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

; sfc16 is simple ;)

BARREL_SHIFT=6
RSHIFT=5
LSHIFT=3

.proc sfc16
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
    dta 0, 0
xc_lshift
    dta 0, 0
xc_barrel_lshift
    dta 0, 0
xc_barrel_rshift
    dta 0, 0
tmp
    dta 0, 0

.endp

; -----------------------------------------------------------------------------

.print 'random: ', RANDOM_START, '-', *-1, ' (', *-RANDOM_START, ')'
