; -----------------------------------------------------------------------------
; ***** MACROS *****
; -----------------------------------------------------------------------------

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

.macro sub32 srcloc subloc dstloc
    sec
    .rept 4, #-1
    lda :srcloc+#
    sbc :subloc+#
    sta :dstloc+#
    .endr
.endm

.macro ror32_8 loc
    ldx :loc+0

    mva :loc+1 :loc+0
    mva :loc+2 :loc+1
    mva :loc+3 :loc+2

    stx :loc+3
.endm

.macro ror32 loc times
    ldx #:times
@
    lsr :loc+3
    ror :loc+2
    ror :loc+1
    ror :loc
    bcc noC
    lda :loc+3
    adc #$7f        ; $7f+C=$80
    sta :loc+3
noC
    dex
    bne @-
.endm
