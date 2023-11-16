#! /bin/sh

set -e

for i in 0 1 2 3 4 5 6; do
    echo "testing algorithm $i"
    ./rnddata $i 9223372036854775807 | ./testu01 > raw$i.u01 &
done

wait `jobs -p`
