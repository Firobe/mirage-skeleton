set title 'Mirage network benchmark'
set terminal png enhanced large
set output 'graph.png'
set xlabel 'Number of threads'
set ylabel 'Bytes/ms'
plot 'unikraft_data.dat' title 'Unikraft' with line, \
     'solo5_data.dat' title 'Solo5' with line
