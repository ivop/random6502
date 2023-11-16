#! /bin/bash

names=`tail -n +9 raw0.report  | grep '|' | cut -d'|' -f1,2 | sed 's/|[ ]*/_/g' | sed 's/_0//g'`
res0=`tail -n +9 raw0.report  | grep '|' | cut -d'|' -f6`
res1=`tail -n +9 raw1.report  | grep '|' | cut -d'|' -f6`
res2=`tail -n +9 raw2.report  | grep '|' | cut -d'|' -f6`
res3=`tail -n +9 raw3.report  | grep '|' | cut -d'|' -f6`
res4=`tail -n +9 raw4.report  | grep '|' | cut -d'|' -f6`
res5=`tail -n +9 raw5.report  | grep '|' | cut -d'|' -f6`
res6=`tail -n +9 raw6.report  | grep '|' | cut -d'|' -f6`

echo "| test | eor | eor4 | sfc16 | chacha20(8) | chacha20(12) | chacha20 | jfs32 |"
echo "| --- | --- | --- | --- | --- | --- | --- | --- |"

for i in `seq 1 114` ; do
    name=`echo $names | cut -d' ' -f$i`
    r0=`echo $res0 | cut -d' ' -f$i`
    r1=`echo $res1 | cut -d' ' -f$i`
    r2=`echo $res2 | cut -d' ' -f$i`
    r3=`echo $res3 | cut -d' ' -f$i`
    r4=`echo $res4 | cut -d' ' -f$i`
    r5=`echo $res5 | cut -d' ' -f$i`
    r6=`echo $res6 | cut -d' ' -f$i`
    echo "| $name | $r0 | $r1| $r2 | $r3 | $r4 | $r5 | $r6 |"
done | sed -e 's/FAILED/:x:/g' -e 's/WEAK/:blue_square:/g' -e 's/PASSED/:white_check_mark:/g'
