# TCP transfer speed benchmark

This unikernel is a variation of the one found in `device-usage/network`. It
starts a TCP server on a given port and for each incoming connection, reads data
in a loop until the connection is closed. The data is discarded immediately but
the amount of data received is counted. Every second or when a connection
closes, the amount of data transferred over all connections since the last
report is reported on stdout.

The benchmark methodology is then to run the server, open a variable number of
simultaneous connections (with OpenBSD's `netcat`) each transferring a fixed
amount of null bytes (to avoid a CPU bottleneck on generating random data for
example), and measuring the average transfer rate over all connections.

### Requirements

- `dd` is used to generate the input data for each connection
- `nc` (the OpenBSD variant) is used to create clients to the unikernel
- a working `tap0` device is expected (on Linux it can be created by running the
  `./setup-network.sh` script). The script can be tweaked if your device has a
  different name.
- the unikernel is expected to be reachable from the host (no firewall or
  networking rules preventing access)
- `awk` is needed to process unikernel output. This has only been tested with GNU
    `awk` (`gawk`).
- GNU `parallel` is needed to launch multiple instances of `nc`
- If benchmarking the `unikraft-qemu` target, you will need `qemu-system-x86_64`
    or `qemu-system-aarch64` available in your `PATH`.
- `gnuplot` is needed to visualize the results

## Running the benchmarks and visualizing the results

Simply run `./run.sh`. This will build the `unikraft-qemu`, `hvt` and `spt`
targets if not present already, and run the benchmark for varying numbers of
simultaneous connections.

A graph with the results will be generated as `graph.png` (the numbers of
written in `.dat` files in the current folder).
