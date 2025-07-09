#!/bin/bash -x

ip link add br0 type bridge
ip tuntap add dev tap0 mode tap
ip link set dev tap0 master br0
ip addr add 10.0.0.1/24 dev br0
ip link set dev br0 up
ip link set dev tap0 up
