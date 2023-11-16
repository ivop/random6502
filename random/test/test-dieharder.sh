#! /bin/sh

set -e

for i in 0 1 2 3 ; do
    echo "testing algorithm $i"
    ./rnddata $i 9223372036854775807 | dieharder -f /dev/stdin -g 201 -a > raw$i.report &
done

wait `jobs -p`
