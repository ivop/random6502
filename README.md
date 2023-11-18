## Pseudo Random Number Generators in 6502 assembly

This repository contains several PRNGs (Pseudo Random Number Generators) written in 6502 assembly.
Because I was not happy with the quality of the available generators, I wrote a few more modern ones.
The code was written for the Atari 8-bit with [Mad-Assembler](https://github.com/tebe6502/Mad-Assembler), but should be easy to port to other 6502 based systems.
Add *opt h-* to suppress Atari 8-bit headers, and output raw binary data.

### Overview

<table>
    <thead>
        <tr>
            <th rowspan=2>Generator</th>
            <th rowspan=2>Bits</th>
            <th rowspan=2>Size</th>
            <th rowspan=2>ZP</th>
            <th colspan=2>Speed</th>
            <th rowspan=2>Quality</th>
            <th rowspan=2>Notes</th>
        </tr>
        <tr>
            <th>Seed</th>
            <th>Generate<br>(min/max/avg)</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>single_eor</td>
            <td>8</td>
            <td>17</td>
            <td>1</td>
            <td>15</td>
            <td>23/28/27</td>
            <td>:x:</td>
            <td></td>
        </tr>
        <tr>
            <td>four_taps_eor</td>
            <td>8</td>
            <td>37</td>
            <td>1</td>
            <td>15</td>
            <td>56/60/58</td>
            <td>:x:</td>
            <td></td>
        </tr>
        <tr>
            <td>sfc16</td>
            <td>16</td>
            <td>226 :thumbsup:</td>
            <td>12</td>
            <td>3292</td>
            <td>27/350/186</td>
            <td>:star: :star:</td>
            <td>smallest</td>
        </tr>
        <tr>
            <td>chacha20(8)</td>
            <td>32</td>
            <td>2559</td>
            <td>64</td>
            <td>708</td>
            <td>29/18775/321</td>
            <td>:star: :star: :star: :star: :star:</td>
            <td rowspan=3 >crypto, random access</td>
        </tr>
        <tr>
            <td>chacha20(12)</td>
            <td>32</td>
            <td>2559</td>
            <td>64</td>
            <td>708</td>
            <td>29/27662/459</td>
            <td>:star: :star: :star: :star: :star:</td>
        </tr>
        <tr>
            <td>chacha20(20)</td>
            <td>32</td>
            <td>2559</td>
            <td>64</td>
            <td>708</td>
            <td>29/45352/736</td>
            <td>:star: :star: :star: :star: :star:</td>
        </tr>
        <tr>
            <td>jsf32</td>
            <td>32</td>
            <td>355</td>
            <td>24</td>
            <td>8020</td>
            <td>29/310/124 :thumbsup:</td>
            <td>:star: :star: :star:</td>
            <td>fastest</td>
        </tr>
        <tr>
            <td>arbee</td>
            <td>64</td>
            <td>600</td>
            <td>56</td>
            <td>14151</td>
            <td>29/1198/171</td>
            <td>:star: :star: :star: :star:</td>
            <td>entropy pooling</td>
        </tr>
    </tbody>
</table>

### Bits

This is the internal word size. Each generator outputs bytes.
Larger word sizes are buffered and returned as bytes.
The most significant byte first, down to the least significant one, after which a new word is calculated on the next call.

### Size

This is the size of all 6502 code, including variables or constant data that is not in zero page.
Algorithms with large tables, like efiix or hc256, are avoided.

### ZP

The amount of bytes needed in zero page.
Most of the time this is the internal state, sometimes combined with space for a few temporary variables for speed during calculation.

### Speed

This is the time it takes to generate and store 4096 bytes.
The test code runs on an unmodified Atari 8-bit with at least 48kB of RAM.
Screen DMA is disabled (no ANTIC cycle stealing), but the OS VBI still runs to keep track of time.
Most loops are unrolled.
Rotates that are larger than half the word size are inverted (left becomes right).
Those that are a multiple of 8 are replaced by moves.
Moves and rotates are combined when possible.
Non-multiples of 8 are split into a multiple of 8 and a residue (which might be shifting a few places back, too).

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

6502 implementations of sfc16, chacha20, jsf32, and arbee are Copyright © 2023 by Ivo van Poorten.

sfc16, chacha20, jsf32, and arbee based on C++ code Copyright © by Chris Doty-Humphrey.  
jsf32's C++ code is mostly by Robert Jenkins.  
All are public domain. See https://pracrand.sourceforge.net/

single_eor is Copyright © by White Flame, https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng  
four_taps_eor is Copyright © 2002 by Lee E. Davison, https://philpem.me.uk/leeedavison/6502/prng/index.html  

