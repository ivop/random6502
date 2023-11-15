#! /bin/sh

set -e

# six tests, eight cores, run parallel

for i in `seq 0 5` ; do
    echo "testing algorithm $i"
    dieharder -f raw$i.dat -g 201 -a > raw$i.report &
done

wait `jobs -p`
