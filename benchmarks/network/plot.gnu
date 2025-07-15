set title 'Mirage network benchmark (receiving 512M of zeros per connection.)'
set terminal png enhanced large
set output 'graph.png'
set xlabel 'Simultaneous connections'
set ylabel 'Bytes received per second'
set format y '%.0s%cB'
plot 'unikraft_data.dat' title 'Unikraft' with line, \
     'hvt_data.dat' title 'solo5-hvt' with line, \
     'spt_data.dat' title 'solo5-spt' with line
