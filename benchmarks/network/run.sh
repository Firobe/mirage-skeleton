#!/bin/bash

DATA_UK=unikraft_data.dat
DATA_HVT=hvt_data.dat
DATA_SPT=spt_data.dat

build_hvt ()
{
    mirage configure -t hvt
    make
}

build_unikraft ()
{
    mirage configure -t unikraft-qemu
    make
}

build_spt ()
{
    mirage configure -t spt
    make
}

run_hvt ()
{
    solo5-hvt --net:service=tap0 -- dist/network.hvt --ipv4=10.0.0.2/24
}

run_spt ()
{
    solo5-spt --net:service=tap0 -- dist/network.spt --ipv4=10.0.0.2/24
}

get_qemu_options () {
    arch=$(uname -m)
    mem="1G"
    common="-cpu host --enable-kvm -nographic -nodefaults -serial stdio -m $mem"
    cmd="qemu-system-$arch"
    case "$arch" in
      x86_64)
	    add_options=""
	    ;;
	  aarch64)
	    add_options="-M virt"
	    ;;
	  *)
	    echo "unknown arch $arch for qemu"
	    exit 1
    esac
    echo -n "$cmd $common $add_options"
}

run_unikraft ()
{
    QEMU=$(get_qemu_options)
    $QEMU \
      -netdev tap,id=hnet0,ifname=tap0,vhost=off,script=no,downscript=no \
      -device virtio-net-pci,netdev=hnet0,id=net0                        \
      -kernel dist/network.qemu -append "--ipv4-only=true"
}

filter_output ()
{
(awk 'BEGIN { N = 0; S = 0; T = 0}
          {if ($4 ~ "Read") N++; SIZE += $5; TIME += $8 }
          END { printf "%s\n", int(SIZE / N) / int(TIME / N) * 1000}' >> "$1")
}

send ()
{
    parallel -N0 'dd if=/dev/zero bs=64M count=8 iflag=fullblock | nc -nq0 10.0.0.2 8080' ::: $(seq "$1")
}

bench_unikraft ()
{
    echo "bench unikraft $1"
    printf "%s\t" "$1" >> $DATA_UK;
    run_unikraft | filter_output $DATA_UK &
    send "$1"
    sleep 1s
    pkill 'qemu-system.*'
    sleep 1s
}

bench_hvt ()
{
    echo "bench hvt $1"
    printf "%s\t" "$1" >> $DATA_HVT;
    run_hvt | filter_output $DATA_HVT &
    send "$1"
    sleep 1s
    pkill 'solo5'
    sleep 1s
}

bench_spt ()
{
    echo "bench spt $1"
    printf "%s\t" "$1" >> $DATA_SPT;
    run_spt | filter_output $DATA_SPT &
    send "$1"
    sleep 1s
    pkill 'solo5'
    sleep 1s
}

[ -f "dist/network.qemu" ] || build_unikraft

printf "# %s\t%s\n" "N" "SPEED" > $DATA_UK
bench_unikraft 1
bench_unikraft 2
bench_unikraft 3
bench_unikraft 4
bench_unikraft 8

[ -f "dist/network.hvt" ] || build_hvt

printf "# %s\t%s\n" "N" "SPEED" > $DATA_HVT
bench_hvt 1
bench_hvt 2
bench_hvt 3
bench_hvt 4
bench_hvt 8

[ -f "dist/network.spt" ] || build_spt

printf "# %s\t%s\n" "N" "SPEED" > $DATA_SPT
bench_spt 1
bench_spt 2
bench_spt 3
bench_spt 4
bench_spt 8

gnuplot plot.gnu
