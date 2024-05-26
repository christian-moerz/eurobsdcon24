#!/bin/sh

# create a zfs volume if it does not exist
if [ ! -e /labs/freebsd-vm ]; then
	zfs create zroot/labjails/freebsd-vm
fi

# Set up a disk for a virtual machine setup
truncate -s 20G /labs/freebsd-vm/disk.img

