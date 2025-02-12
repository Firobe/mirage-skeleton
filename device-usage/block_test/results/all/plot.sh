#!/bin/sh
cat << EOF > /tmp/plot
set title "Benchmark copying 100M of data"
set logscale x 10
set xlabel "buffer size (number of sectors)"
set ylabel "time (s)"
set yrange [0:]
plot \
    'hvt-para' with lp title 'solo5-hvt parallel', \
    'hvt-serial' with lp title 'solo5-hvt serial', \
    'spt-para' with lp title 'solo5-spt parallel', \
    'spt-serial' with lp title 'solo5-spt serial'
EOF
gnuplot --persist /tmp/plot
