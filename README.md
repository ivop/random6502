# Pseudo Random Number Generators in 6502 assembly

This repository contains several PRNGs (Pseudo Random Number Generators) written in 6502 assembly.
Because I was not happy with the quality of the available generators, I wrote a few more modern ones.
The code was written for the Atari 8-bit with [Mad-Assembler](https://github.com/tebe6502/Mad-Assembler), but should be easy to port to other 6502 based systems.
Add *opt h-* to suppress Atari 8-bit headers, and output raw binary data.

### Overview

| Generator | Code size | ZP usage | 4096 bytes | Quality |
| --- | --- | --- | --- | --- |
| single_eor | 17 | 1 | 0.14s | :x: |
| four_taps_eor | 37 | 1 | 0.22s | :x: |
| sfc16 | 226 :thumbsup: | 12 | 0.54s | :star: :star: |
| chacha20(8) | 2559 | 64 | 0.88s | :star: :star: :star: :star: :star: |
| chacha20(12) | 2559 | 64 | 1.24s | :star: :star: :star: :star: :star: |
| chacha20(20) | 2559 | 64 | 1.96s | :star: :star: :star: :star: :star: |
| jsf32 | 355 | 24 | 0.38s :thumbsup: | :star: :star: :star: |
| arbee | 600 | 56 | 0.50s | :star: :star: :star: :star: |

### Quality

**single_eor** and **four_taps_eor** are pretty bad. They fail every single test suite.

**sfc17**, **chacha20**, **jsf32**, and **arbee** are all very good. The star rating is relative to eachother.
They all pass TestU01's Alphabit, Rabbit, FIPS 140-2, SmallCrush, Crush, and BigCrush.
They also pass PractRand's RNG_test (>1TB, chacha20 >4TB), gjrand's mcp, and the old dieharder test suite.
See https://pracrand.sourceforge.net/RNG_engines.txt for a detailed description and analysis, and
https://pracrand.sourceforge.net/Tests_results.txt for test results.

In short, **chacha20** is the best of the generators in this repo, then **arbee** (which basically is jsf64 with a counter), then **jsf32**, and finally **sfc16**.
In terms of speed, ignoring the bad PRNGs, **jsf32** is the fastest. In terms of code size and ZP usage, **sfc16** wins.

### Perspective

The 6502 was launched in September 1975. An unmodified Atari 8-bit with a 6502 clocked at ±1.8Mhz, display DMA disabled, and VBI enabled for the timer, needs ± 31317 hours to generate 1TB of data (3 years, 209 days and 21 hours) with the jsf32 generator. For perspective, my x86_64 machine (Octacore AMD FX-8320 3.5GHz, launched October 2012) does that in about an hour on a single core.

### Credits

6502 implementations of sfc16, chacha20, and jsf32 are Copyright © 2023 by Ivo van Poorten.

sfc16, chacha20, and jsf32 based on C++ code Copyright © by Chris Doty-Humphrey.  
jsf32's C++ code is mostly by Robert Jenkins.  
Both are public domain. See https://pracrand.sourceforge.net/

single_eor is Copyright © by White Flame, https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng  
four_taps_eor is Copyright © 2002 by Lee E. Davison, https://philpem.me.uk/leeedavison/6502/prng/index.html  

