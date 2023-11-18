
    opt h-

    org $0200

table
    jsr random_single_eor_seed
    nop
    jsr random_single_eor
    nop

    jsr random_four_taps_eor_seed
    nop
    jsr random_four_taps_eor
    nop

    jsr random_sfc16_seed
    nop
    jsr random_sfc16
    nop

    jsr wrapper_random_chacha20_8_seed
    nop
    jsr random_chacha20
    nop

    jsr wrapper_random_chacha20_12_seed
    nop
    jsr random_chacha20
    nop

    jsr wrapper_random_chacha20_20_seed
    nop
    jsr random_chacha20
    nop

    jsr random_jsf32_seed
    nop
    jsr random_jsf32
    nop

    jsr random_arbee_seed
    nop
    jsr random_arbee
    nop

.proc wrapper_random_chacha20_8_seed
    mvy #8/2 random_chacha20_core.rounds
    jmp random_chacha20_seed
.endp

.proc wrapper_random_chacha20_12_seed
    mvy #12/2 random_chacha20_core.rounds
    jmp random_chacha20_seed
.endp

.proc wrapper_random_chacha20_20_seed
    mvy #20/2 random_chacha20_core.rounds
    jmp random_chacha20_seed
.endp

.define RANDOM_ENABLE_SINGLE_EOR
.define RANDOM_ENABLE_FOUR_TAPS_EOR
.define RANDOM_ENABLE_SFC16
.define RANDOM_ENABLE_CHACHA20
.define RANDOM_ENABLE_JSF32
.define RANDOM_ENABLE_ARBEE

RANDOM_ZERO_PAGE=0

    icl 'random.s'
