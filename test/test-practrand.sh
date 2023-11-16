#! /bin/sh

set -e

for i in 0 1 2 3 4 5 6; do
    echo "testing algorithm $i"
    ./rnddata $i 9223372036854775807 | RNG_test stdin > raw$i.pr &
done

wait `jobs -p`
