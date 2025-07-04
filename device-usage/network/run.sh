#!/bin/bash

ASSETS=assets/shakespeare.txt
DATA_UK=unikraft_data.dat
DATA_SOLO=solo5_data.dat

build_solo5 ()
{
  mirage configure -t hvt
  make
}

build_unikraft ()
{
  mirage configure -t unikraft-qemu
  make
}

run_solo5 ()
{
  solo5-hvt --net:service=tap0 -- dist/network.hvt --ipv4=10.0.0.2/24
}

run_unikraft ()
{
    qemu-system-x86_64 -nographic -nodefaults -serial stdio -machine q35 \
      -cpu "qemu64,-vmx,-svm,+x2apic,+pdpe1gb,+rdrand,+rdseed" -m 1G     \
      -netdev tap,id=hnet0,ifname=tap0,vhost=off,script=no,downscript=no \
      -device virtio-net-pci,netdev=hnet0,id=net0                        \
      -kernel dist/network.qemu -append "--ipv4-only=true"
}

filter_output ()
{
(awk 'BEGIN { N = 0; S = 0; T = 0}
          {if ($4 ~ "Read") N++; SIZE += $5; TIME += $8 }
          END { printf "%s\n", int(SIZE / N) / int(TIME / N)}' >> $1)
}

dump ()
{
  for ((i = 0; i <= 15; i++));
  do
    cat $ASSETS
  done
}

send ()
{
  for ((i = 0; i <= $1; i++));
  do
    dump | nc -nw1 10.0.0.2 8080 &
  done
}

bench_unikraft ()
{
(sleep 15; pkill 'qemu-system.*') &
    (sleep 2s;            \
      send $1;
      sleep 1s;) &
    printf "%s\t" $1 >> $DATA_UK;
    run_unikraft | filter_output $DATA_UK
}

bench_solo5 ()
{
  (sleep 15; pkill 'solo5*') &
  (sleep 2s;
  send $1;
  sleep 1s;) &
  printf "%s\t" $1 >> $DATA_SOLO;
  run_solo5 | filter_output $DATA_SOLO

}

[ -f "dist/network.qemu" ] || build_unikraft

printf "# %s\t%s\n" "N" "SPEED" > $DATA_UK
bench_unikraft 1
bench_unikraft 10
bench_unikraft 20
bench_unikraft 30
bench_unikraft 40
bench_unikraft 50
bench_unikraft 60
bench_unikraft 70
bench_unikraft 80
bench_unikraft 90
bench_unikraft 100

[ -f "dist/network.hvt" ] || build_solo5

printf "# %s\t%s\n" "N" "SPEED" > $DATA_SOLO
bench_solo5 1
bench_solo5 10
bench_solo5 20
bench_solo5 30
bench_solo5 40
bench_solo5 50
bench_solo5 60
bench_solo5 70
bench_solo5 80
bench_solo5 90
bench_solo5 100

gnuplot plot.gnu
