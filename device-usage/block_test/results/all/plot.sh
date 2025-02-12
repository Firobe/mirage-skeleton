#!/bin/sh
cat << EOF > /tmp/plot
set title "Time to copy 100M of random data (avg. over >=10 runs)"
set logscale x 10
set xlabel "buffer size (number of sectors)"
set ylabel "time (s)"
set yrange [0:]
plot \
    'hvt-para' with lp title 'solo5-hvt parallel', \
    'hvt-serial' with lp title 'solo5-hvt serial', \
    'spt-para' with lp title 'solo5-spt parallel', \
    'spt-serial' with lp title 'solo5-spt serial', \
    '10ms-para' with lp title '10ms sleep parallel', \
    '10ms-serial' with lp title '10ms sleep serial'
EOF
gnuplot --persist /tmp/plot
