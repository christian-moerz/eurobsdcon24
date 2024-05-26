#!/bin/sh

set -x

# create a zfs volume if it does not exist
mount | grep freebsd-vm > /dev/null
if [ ! -e /labs/freebsd-vm ]; then
	zfs create zroot/labjails/freebsd-vm
	zfs mount zroot/labjails/freebsd-vm
fi

# Set up a disk for a virtual machine setup
truncate -s 20G /labs/freebsd-vm/disk.img

