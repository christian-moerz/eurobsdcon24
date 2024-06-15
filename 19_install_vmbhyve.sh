#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

# Install vm-bhyve package manager
pkg install -y vm-bhyve

# Configure vm-bhyve
sysrc vm_enable="YES"
sysrc vm_dir="zfs:${ZPOOL}/${ZSTOREVOL}"


