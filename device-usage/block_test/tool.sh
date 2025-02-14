#!/bin/bash
FILESIZE=50M
BENCH_DIR=results/
BENCH_NAME="${BENCH_NAME:-laptop}"
FIRECRACKER="./firecracker/firecracker-v1.7.0-x86_64"

make_fc_config () {
    cat << EOF > /tmp/fc.json
{
  "boot-source": {
    "kernel_image_path": "dist/block_test.fc",
    "boot_args": "dist/block_test.fc -- --buffsize $1 --parallel $2 --logs error",
    "initrd_path": null
  },
  "drives": [
      {
          "drive_id": "block0",
          "path_on_host": "block0",
          "is_root_device": false,
          "is_read_only": false
      },
      {
          "drive_id": "block1",
          "path_on_host": "block1",
          "is_root_device": false,
          "is_read_only": false
      }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 4096,
    "smt": false,
    "track_dirty_pages": false,
    "huge_pages": "None"
  },
  "cpu-config": null,
  "balloon": null,
  "network-interfaces": [],
  "vsock": null,
  "logger": null,
  "metrics": null,
  "mmds-config": null,
  "entropy": null
}
EOF
}

do_run () {
    case $1 in
        hvt | spt)
            solo5-"$1" \
                --block:block0=block0 \
                --block:block1=block1 \
                "dist/block_test.$1" \
                --buffsize "$2" \
                --parallel "$3" > log.txt
            ;;
        qemu)
            # kill qemu when 'done' is printed
            tail -f log.txt | grep 'done' -m 1 &> /dev/null && pkill qemu &
            qemu-system-x86_64 -cpu host -m 4G --enable-kvm -nographic -nodefaults -serial stdio \
                -kernel dist/block_test.qemu -append "--buffsize $2 --parallel $3 --logs error" \
                -drive file=block0,if=virtio,id=hvirtio0,format=raw \
                -drive file=block1,if=virtio,id=hvirtio1,format=raw &> log.txt
            ;;
        fc)
            # kill firecracker when 'done' is printed
            tail -f log.txt | grep 'done' -m 1 &> /dev/null && pkill firecracker &
            # firecracker doesn't support more than 8 sectors at a time
            if [ "$2" -gt 8 ]; then
                make_fc_config 8 "$3"
            else
                make_fc_config "$2" "$3"
            fi
            $FIRECRACKER --no-api --config-file "/tmp/fc.json" &> log.txt
            ;;
        *)
            echo "unknown format $1"
            exit 1
            ;;
    esac
}

do_bench () {
    mkdir -p "$BENCH_DIR/$BENCH_NAME"
    # Bench all unikernel kinds
    for kind in qemu fc spt hvt; do
        binary_file="dist/block_test.$kind"
        if [ ! -f "$binary_file" ]; then
            echo "Unikernel file $binary_file not found, skipping this category."
            continue
        fi
        # Try running Lwt copies in parallel or not
        for parallel in true false; do
            filename="$BENCH_DIR/$BENCH_NAME/$kind-$parallel.dat"
            rm -f "$filename"
            touch "$filename"
            # Scan through various buffer sizes
            for buffsize in 1 2 5 10 20 50 100 200 500 1000 2000; do
                sum=0
                # Average 10 runs
                for run in {1..10}; do
                    # Prepare new random data to copy each time, to flush caches
                    echo -n "[$kind][$parallel] SIZE $buffsize ($run/10)... "
                    dd if=/dev/urandom of=block0 bs=$FILESIZE count=1 iflag=fullblock &> /dev/null
                    dd if=/dev/urandom of=block1 bs=$FILESIZE count=1 iflag=fullblock &> /dev/null
                    # Run with logs in log.txt
                    rm -f log.txt && touch log.txt
                    do_run $kind $buffsize $parallel
                    # Get time from logs
                    time=$(grep 'done' < log.txt | sed 's/.*done: \([0-9]\+\).*/\1/')
                    echo "$time ns"
                    sum=$((sum + time))
                done
                avg=$((sum / 10))
                echo "Average $avg ns"
                echo "$buffsize $avg" >> "$filename"
            done
        done
    done
}

do_plot () {
    pfx="$BENCH_DIR/$BENCH_NAME"
    cat << EOF > /tmp/plot
set title "Time to copy $FILESIZE of random data (avg. over 10 runs)"
set logscale x 10
set key font ",6"
set xlabel "buffer size (number of sectors)"
set ylabel "time (s)"
set yrange [0:0.7]
plot \
    '$pfx/hvt-true.dat' u 1:(\$2/1000000000) with lp title 'solo5-hvt parallel', \
    '$pfx/hvt-false.dat' u 1:(\$2/1000000000) with lp title 'solo5-hvt serial', \
    '$pfx/spt-true.dat' u 1:(\$2/1000000000) with lp title 'solo5-spt parallel', \
    '$pfx/spt-false.dat' u 1:(\$2/1000000000) with lp title 'solo5-spt serial', \
    '$pfx/fc-true.dat' u 1:(\$2/1000000000) with lp title 'unikraft-firecracker parallel', \
    '$pfx/fc-false.dat' u 1:(\$2/1000000000) with lp title 'unikraft-firecracker serial', \
    '$pfx/qemu-true.dat' u 1:(\$2/1000000000) with lp title 'unikraft-qemu parallel', \
    '$pfx/qemu-false.dat' u 1:(\$2/1000000000) with lp title 'unikraft-qemu serial'
EOF
    gnuplot --persist /tmp/plot
}

case $1 in
    bench)
        do_bench
        ;;
    plot)
        do_plot
        ;;
    *)
        echo "usage: $0 [bench|plot]"
        ;;
esac

