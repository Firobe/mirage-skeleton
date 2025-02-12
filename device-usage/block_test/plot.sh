#!/bin/sh
cat << EOF > /tmp/plot
set title "Time to copy 10M of random data (avg. over 10 runs)"
set logscale x 10
set xlabel "buffer size (number of sectors)"
set ylabel "time (s)"
set yrange [0:0.2]
plot \
    'hvt-true.dat' u 1:(\$2/1000000000) with lp title 'solo5-hvt parallel', \
    'hvt-false.dat' u 1:(\$2/1000000000) with lp title 'solo5-hvt serial', \
    'spt-true.dat' u 1:(\$2/1000000000) with lp title 'solo5-spt parallel', \
    'spt-false.dat' u 1:(\$2/1000000000) with lp title 'solo5-spt serial', \
    'qemu-true.dat' u 1:(\$2/1000000000) with lp title 'mirage-unikraft parallel', \
    'qemu-false.dat' u 1:(\$2/1000000000) with lp title 'mirage-unikraft serial'
EOF
gnuplot --persist /tmp/plot
