#! /bin/sh

set -e

SIZE=104857600

make rnddata

for i in `seq 0 5` ; do
    echo "Generate $SIZE bytes of algorithm $i"
    ./rnddata $i $SIZE > raw$i.dat
done
