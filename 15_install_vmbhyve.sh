#!/bin/sh

# Install vm-bhyve package manager
pkg install -y vm-bhyve

# Configure vm-bhyve
sysrc vm_enable="YES"
sysrc vm_dir="zfs:zroot/labjails"


