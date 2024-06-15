#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labdisk}

# create a zfs volume if it does not exist
mount | grep freebsd-vm > /dev/null
if [ ! -e ${ZPATH}/freebsd-vm ]; then
	zfs create ${ZPOOL}/${ZSTOREVOL}/freebsd-vm
	zfs mount ${ZPOOL}/${ZSTOREVOL}/freebsd-vm
fi

# Set up a disk for a virtual machine setup
truncate -s 20G ${ZPATH}/freebsd-vm/disk.img

