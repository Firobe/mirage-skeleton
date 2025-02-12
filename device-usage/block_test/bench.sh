#!/bin/sh
EXT=hvt
FILESIZE=100M
make build
for parallel in true false; do
    hyperfine \
        -L BUFFSIZE 1,2,5,10,50,100,200,500,1000,2000 \
        --prepare "dd if=/dev/urandom of=storage1 bs=$FILESIZE count=1 iflag=fullblock && \
                   dd if=/dev/urandom of=storage2 bs=$FILESIZE count=1 iflag=fullblock" \
        --export-csv "parallel_$parallel.csv" \
        "solo5-$EXT \
            --block:storage1=storage1 \
            --block:storage2=storage2 \
            dist/block_test.$EXT \
            --buffsize {BUFFSIZE} \
            --parallel $parallel"
done
