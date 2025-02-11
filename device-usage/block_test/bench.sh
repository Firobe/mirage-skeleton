#!/bin/sh
FILESIZE=100M
make build
hyperfine \
    -L BUFFSIZE 1,10,50,100,200 \
    --prepare "dd if=/dev/urandom of=storage1 bs=$FILESIZE count=1 iflag=fullblock && \
               dd if=/dev/urandom of=storage2 bs=$FILESIZE count=1 iflag=fullblock" \
    --export-markdown out.md \
    'solo5-hvt \
        --block:storage1=storage1 \
        --block:storage2=storage2 \
        dist/block_test.hvt \
        --buffsize {BUFFSIZE}'
