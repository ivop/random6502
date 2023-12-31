; -----------------------------------------------------------------------------
; ***** MACROS *****
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; ***** 8-BIT MATH *****
; -----------------------------------------------------------------------------

.macro ror8_1 loc
    lsr :loc
    bcc noC
    lda :loc
    ora #$80
    sta :loc
noC
.endm

.macro ror8_3 loc
    ror8_1 :loc
    ror8_1 :loc
    ror8_1 :loc
.endm

; -----------------------------------------------------------------------------
; ***** 32-BIT MATH *****
; -----------------------------------------------------------------------------

.macro add32 srcloc addloc dstloc
    clc
    .rept 4
    lda :srcloc+#
    adc :addloc+#
    sta :dstloc+#
    .endr
.endm

.macro xor32 srcloc xorloc dstloc
    .rept 4
    lda :srcloc+#
    eor :xorloc+#
    sta :dstloc+#
    .endr
.endm

.macro rol32_1 loc
    asl :loc
    rol :loc+1
    rol :loc+2
    rol :loc+3
    lda :loc
    adc #0
    sta :loc
.endm

.macro rol32 loc times
    ldx #:times
@
    rol32_1 :loc
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

.macro xo32rol32_16 loc xorloc
    lda :loc
    eor :xorloc
    tax
    lda :loc+1
    eor :xorloc+1
    tay

    lda :loc+2
    eor :xorloc+2
    sta :loc
    lda :loc+3
    eor :xorloc+3
    sta :loc+1

    stx :loc+2
    sty :loc+3
.endm

.macro rol32_8 loc
    ldx :loc+3

    mva :loc+2 :loc+3
    mva :loc+1 :loc+2
    mva :loc+0 :loc+1

    stx :loc+0
.endm

.macro xor32rol32_8 loc xorloc
    lda :loc+3
    eor :xorloc+3
    tax

    lda :loc+2
    eor :xorloc+2
    sta :loc+3
    lda :loc+1
    eor :xorloc+1
    sta :loc+2
    lda :loc
    eor :xorloc
    sta :loc+1

    stx :loc
.endm

.macro sub32 srcloc subloc dstloc
    sec
    .rept 4
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

.macro ror32_1 loc
    lsr :loc+3
    ror :loc+2
    ror :loc+1
    ror :loc
    bcc noC
    lda :loc+3
    adc #$7f        ; $7f+C=$80
    sta :loc+3
noC
.endm

.macro ror32 loc times
    ldx #:times
@
    ror32_1 :loc
    dex
    bne @-
.endm


.macro movror32_8 src dst
    lda :src+0
    sta :dst+3
    lda :src+1
    sta :dst+0
    lda :src+2
    sta :dst+1
    lda :src+3
    sta :dst+2
.endm

.macro movror32_16 src dst
    lda :src+0
    sta :dst+2
    lda :src+1
    sta :dst+3
    lda :src+2
    sta :dst+0
    lda :src+3
    sta :dst+1
.endm

.macro movrol32_16 src dst
    movror32_16 :src :dst
.endm

.macro movrol32_17 src dst
    lda :src+0
    asl
    sta :dst+2
    lda :src+1
    rol
    sta :dst+3
    lda :src+2
    rol
    sta :dst+0
    lda :src+3
    rol
    sta :dst+1
    bcc noC
    lda :dst+2
    ora #1
    sta :dst+2
noC
.endm

.macro movrol32_17_xor src xorloc dst
    lda :src+0
    asl
    sta :dst+2

    lda :src+1
    rol
    eor :xorloc+3
    sta :dst+3

    lda :src+2
    rol
    eor :xorloc+0
    sta :dst+0

    lda :src+3
    rol
    eor :xorloc+1
    sta :dst+1

    lda :dst+2
    bcc noC
    ora #1
noC
    eor :xorloc+2
    sta :dst+2
.endm

.macro inc32 loc
    clc
    lda :loc
    adc #1
    sta :loc
    .rept 3
    bcc early
    lda :loc+1+#
    adc #0
    sta :loc+1+#
    .endr
early
.endm

.macro mov32 src dst
    .rept 4
    lda :src+#
    sta :dst+#
    .endr
.endm

.macro lsr32 loc times
    .rept :times
    lsr :loc+3
    ror :loc+2
    ror :loc+1
    ror :loc
    .endr
.endm

.macro lsr32_8 loc
    lda :loc+1
    sta :loc
    lda :loc+2
    sta :loc+1
    lda :loc+3
    sta :loc+2
    lda #0
    sta :loc+3
.endm

.macro movlsr32_8_xor src xorloc dst
    lda :src+1
    eor :xorloc
    sta :dst
    lda :src+2
    eor :xorloc+1
    sta :dst+1
    lda :src+3
    eor :xorloc+2
    sta :dst+2
    lda #0
    eor :xorloc+3
    sta :dst+3
.endm

.macro asl32 loc times
    .rept :times
    asl :loc
    rol :loc+1
    rol :loc+2
    rol :loc+3
    .endr
.endm

; -----------------------------------------------------------------------------
; ***** 64-BIT MATH *****
; -----------------------------------------------------------------------------

.macro inc64 loc
    clc
    lda :loc
    adc #1
    sta :loc
    .rept 7
    bcc early
    lda :loc+1+#
    adc #0
    sta :loc+1+#
    .endr
early
.endm

.macro mov64 src dst
    .rept 8
    lda :src+#
    sta :dst+#
    .endr
.endm

.macro rol64 loc times
    ldx #:times
@
    asl :loc
    rol :loc+1
    rol :loc+2
    rol :loc+3
    rol :loc+4
    rol :loc+5
    rol :loc+6
    rol :loc+7
    lda :loc
    adc #0
    sta :loc
    dex
    bne @-
.endm

.macro ror64 loc times
    ldx #:times
@
    lsr :loc+7
    ror :loc+6
    ror :loc+5
    ror :loc+4
    ror :loc+3
    ror :loc+2
    ror :loc+1
    ror :loc
    bcc noC
    lda :loc+7
    adc #$7f        ; $7f+C=$80
    sta :loc+7
noC
    dex
    bne @-
.endm

.macro add64 srcloc addloc dstloc
    clc
    .rept 8
    lda :srcloc+#
    adc :addloc+#
    sta :dstloc+#
    .endr
.endm

.macro eor64 srcloc eorloc dstloc
    .rept 8
    lda :srcloc+#
    eor :eorloc+#
    sta :dstloc+#
    .endr
.endm

.macro movror64_16 src dst
    .rept 8
    mva :src+[[2+#]&7] :dst+#
    .endr
.endm

.macro movrol64_16 src dst
    .rept 8
    mva :src+# :dst+[[2+#]&7]
    .endr
.endm

.macro movror64_24 src dst
    .rept 8
    mva :src+[[3+#]&7] :dst+#
    .endr
.endm
