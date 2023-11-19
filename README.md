## Pseudo Random Number Generators in 6502 assembly

This repository contains several PRNGs (Pseudo Random Number Generators) written in 6502 assembly.
Because I was not happy with the quality of the available generators, I wrote a few more modern ones.
The code was written for the Atari 8-bit with [Mad-Assembler](https://github.com/tebe6502/Mad-Assembler), but should be easy to port to other 6502 based systems.
Or add *opt h-* to suppress Atari 8-bit headers, and output raw binary data.
See the generic emulation based test code that makes use of that.

### Overview

<table>
    <thead>
        <tr valign="bottom">
            <th rowspan=3>Generator</th>
            <th rowspan=3>Bits</th>
            <th rowspan=3>Size</th>
            <th rowspan=3>ZP</th>
            <th colspan=4>Speed</th>
            <th rowspan=3>Quality</th>
            <th rowspan=3>Notes</th>
        </tr>
        <tr valign="top">
            <th rowspan=2>Seed</th>
            <th colspan=3>Generate</th>
        </tr>
        <tr>
            <th>Min</th>
            <th>Max</th>
            <th>Avg</th>
        </tr>
    </thead>
    <tbody>
        <tr align="right">
            <td>single_eor</td>
            <td>8</td>
            <td>17</td>
            <td>1</td>
            <td>15</td>
            <td>23</td><td>28</td><td>27</td>
            <td align="left">:x:</td>
            <td align="left"></td>
        </tr>
        <tr align="right">
            <td>four_taps_eor</td>
            <td>8</td>
            <td>37</td>
            <td>1</td>
            <td>15</td>
            <td>56</td><td>60</td><td>58</td>
            <td align="left">:x:</td>
            <td align="left"></td>
        </tr>
        <tr align="right">
            <td>sfc16</td>
            <td>16</td>
            <td><b>180</b></td>
            <td>10</td>
            <td>2432</td>
            <td>27</td><td>243</td><td>132</td>
            <td align="left">⭐⭐</td>
            <td align="left">smallest</td>
        </tr>
        <tr align="right">
            <td>sfc32</td>
            <td>32</td>
            <td>296</td>
            <td>20</td>
            <td>5845</td>
            <td>29</td><td>394</td><td>116</td>
            <td align="left">⭐⭐⭐</td>
            <td align="left"></td>
        </tr>
        <tr align="right">
            <td>chacha20(8)</td>
            <td>32</td>
            <td>2101</td>
            <td>64</td>
            <td>708</td>
            <td>29</td><td>15945</td><td>277</td>
            <td align="left">⭐⭐⭐⭐⭐</td>
            <td rowspan=3  align="left">crypto, random access</td>
        </tr>
        <tr align="right">
            <td>chacha20(12)</td>
            <td>32</td>
            <td>2101</td>
            <td>64</td>
            <td>708</td>
            <td>29</td><td>23450</td><td>393</td>
            <td align="left">:star::star::star::star::star:</td>
        </tr>
        <tr align="right">
            <td>chacha20(20)</td>
            <td>32</td>
            <td>2101</td>
            <td>64</td>
            <td>708</td>
            <td>29</td><td>38376</td><td>627</td>
            <td align="left">⭐⭐⭐⭐⭐</td>
        </tr>
        <tr align="right">
            <td>jsf32</td>
            <td>32</td>
            <td>337</td>
            <td>20</td>
            <td>7332</td>
            <td>29</td><td>376</td><td><b>115</b></td>
            <td align="left">⭐⭐⭐</td>
            <td align="left">fastest</td>
        </tr>
        <tr align="right">
            <td>arbee</td>
            <td>64</td>
            <td>614</td>
            <td>56</td>
            <td>13480</td>
            <td>29</td><td>1143</td><td>164</td>
            <td align="left">⭐⭐⭐⭐</td>
            <td align="left">entropy pooling</td>
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

Times are in clock cycles.
This includes the calling JSR instruction and the returning RTS instruction.

### Quality

**single_eor** and **four_taps_eor** are pretty bad. They fail every single test suite.

**sfc16**, **sfc32**, **chacha20**, **jsf32**, and **arbee** are all very good. The star rating is relative to eachother.
They all pass TestU01's Alphabit, Rabbit, FIPS 140-2, SmallCrush, Crush, and BigCrush.
They also pass PractRand's RNG_test (>1TB, chacha20 >4TB), gjrand's mcp, and the old dieharder test suite.
See https://pracrand.sourceforge.net/RNG_engines.txt for a detailed description and analysis, and
https://pracrand.sourceforge.net/Tests_results.txt for test results.

In short, **chacha20** is the best of the generators in this repo, then **arbee** (which basically is jsf64 with a counter), then **jsf32** and **sfc32**, and finally **sfc16**.
In terms of speed, ignoring the bad PRNGs, **jsf32** is the fastest. In terms of code size and ZP usage, **sfc16** wins.

### Perspective

The 6502 was launched in September 1975. An unmodified Atari 8-bit with a 6502 clocked at ±1.8Mhz, display DMA disabled, and VBI enabled for the timer, needs ± 31317 hours to generate 1TB of data (3 years, 209 days and 21 hours) with the jsf32 generator. For perspective, my x86_64 machine (Octacore AMD FX-8320 3.5GHz, launched October 2012) does that in about an hour on a single core.

### Credits

6502 implementations of sfc16, chacha20, jsf32, and arbee are Copyright © 2023 by Ivo van Poorten.
License us BSD-2-Clause.

sfc16, chacha20, jsf32, and arbee based on C++ code Copyright © by Chris Doty-Humphrey.  
jsf32's C++ code is mostly by Robert Jenkins.  
All are public domain. See https://pracrand.sourceforge.net/

single_eor is Copyright © by White Flame, https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng  
four_taps_eor is Copyright © 2002 by Lee E. Davison, https://philpem.me.uk/leeedavison/6502/prng/index.html  

MCS6502 emulator is Copyright (c) 2019 by Ben Zotto, MIT License.
