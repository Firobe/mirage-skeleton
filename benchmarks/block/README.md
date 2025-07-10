# Block device transfer speed benchmark

This unikernel connects to two distinct block devices (expected to be of the
same size) and copy the entirety of one to the other, measuring the time it
takes to do so.

The buffer size can be customized with `--buffsize`, and it corresponds to the
number of sectors that are requested for each read or write operation.

The transfer can be done either in serial (the default) or parallel mode (with
`--parallel`). In serial mode, the program waits until a chunk of sectors is
read from disk 0 then written to disk 1 before processing the next chunk. In
parallel mode, all operations are scheduled at the same time. This allows
demonstrating the gain of non-blocking I/O operations on some backends that
support it.

### Requirements

- `dd` and a working `/dev/urandom` is needed to create random data to transfer
  for each run (to avoid OS caching)
- If benchmarking the `unikraft-firecracker` target, you will need Firecracker
  1.7.0 (not later versions). You can customize where the script should expect
  the executable with the `FIRECRACKER` variable.
- If benchmarking the `unikraft-qemu` target, you will need `qemu-system-x86_64`
    or `qemu-system-aarch64` available in your `PATH`.
- `gnuplot` is needed to visualize the results

## Running the benchmarks

- Manually build the images for the backends that you want to compare (they
   will be expected in the `dist` folder as usual). Supporter targets are `hvt`,
   `spt`, `unikraft-qemu` and `unikraft-firecracker` (`virtio` is too slow at
   runtime to be even comparable with the others).
- Run `./bench.sh bench`. This will run all available images for various
   combinations of `--parallel` and `--buffsize`, taking the average of 10 runs
   for each data point. The results will be written in `results/BENCH_DIR`
   (where `BENCH_DIR` is an env variable you can customize).

## Visualizing the results

You can display a graph of the results of a given benchmark with gnuplot by
running `BENCH_DIR=... ./bench.sh plot`

Some results are already commited in this repository (see the `results`
subfolders).
