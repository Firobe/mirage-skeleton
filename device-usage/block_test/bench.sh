#!/bin/bash
FILESIZE=10M

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
                -drive file=storage1,if=virtio,id=hvirtio0,format=raw \
                -drive file=storage2,if=virtio,id=hvirtio1,format=raw &> log.txt
            ;;
        *)
            echo "unknown format $1"
            exit 1
            ;;
    esac
}

do_bench () {
    # Bench all unikernel kinds
    for kind in qemu spt hvt; do
        # Try running Lwt copies in parallel or not
        for parallel in true false; do
            filename="$kind-$parallel.dat"
            rm -f "$filename"
            touch "$filename"
            # Scan through various buffer sizes
            for buffsize in 2 5 10 50 100 200 500 1000 2000; do
                sum=0
                # Average 10 runs
                for run in {1..10}; do
                    # Prepare new random data to copy each time, to flush caches
                    echo -n "[$kind][$parallel] Buffer $buffsize $run/10... "
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

do_bench
