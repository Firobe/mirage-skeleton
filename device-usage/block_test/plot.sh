#!/bin/sh
cat << EOF > /tmp/plot
set title "Time to copy 10M of random data (avg. over 10 runs)"
set logscale x 10
set xlabel "buffer size (number of sectors)"
set ylabel "time (ns)"
set yrange [0:200000000]
plot \
    'hvt-true.dat' with lp title 'solo5-hvt parallel', \
    'hvt-false.dat' with lp title 'solo5-hvt serial', \
    'spt-true.dat' with lp title 'solo5-spt parallel', \
    'spt-false.dat' with lp title 'solo5-spt serial', \
    'qemu-true.dat' with lp title 'mirage-unikraft parallel', \
    'qemu-false.dat' with lp title 'mirage-unikraft serial'
EOF
gnuplot --persist /tmp/plot
