
    opt h-

    org $0200

jump_table
    jmp random_single_eor_seed
    jmp random_single_eor

    jmp random_four_taps_eor_seed
    jmp random_four_taps_eor

    jmp random_sfc16_seed
    jmp random_sfc16

    jmp wrapper_random_chacha20_8_seed
    jmp random_chacha20

    jmp wrapper_random_chacha20_12_seed
    jmp random_chacha20

    jmp wrapper_random_chacha20_20_seed
    jmp random_chacha20

    jmp random_jsf32_seed
    jmp random_jsf32

    jmp random_arbee_seed
    jmp random_arbee

.proc wrapper_random_chacha20_8_seed
    mvy #8 random_chacha20_core.rounds
    jmp random_chacha20_seed
.endp

.proc wrapper_random_chacha20_12_seed
    mvy #12 random_chacha20_core.rounds
    jmp random_chacha20_seed
.endp

.proc wrapper_random_chacha20_20_seed
    mvy #20 random_chacha20_core.rounds
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
