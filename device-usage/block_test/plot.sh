#!/bin/sh
cut -d ',' -f2 parallel_true.csv | tail -n +2 > /tmp/paratrue
cut -d ',' -f2 parallel_false.csv | tail -n +2 > /tmp/parafalse
cat parallel_true.csv | sed 's/.*--buffsize \([0-9]\+\).*/\1/' | tail -n +2 > /tmp/xrange
paste /tmp/xrange /tmp/paratrue > /tmp/truefinal
paste /tmp/xrange /tmp/parafalse > /tmp/falsefinal
cat << EOF > /tmp/plot
set title "Benchmark copying 100M of data"
set logscale x 10
set xlabel "buffer size (number of sectors)"
set ylabel "time (s)"
plot '/tmp/truefinal' with lp title 'solo5-hvt parallel', \
     '/tmp/falsefinal' with lp title 'solo5-hvt serial'
EOF
gnuplot --persist /tmp/plot
