#!/bin/sh

set -x

if [ -e config.sh ]; then
	. ./config.sh
fi
ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labjails}
SWITCHNAME=${SWITCHNAME:=vmswitch}

# create a zfs volume if it does not exist
mount | grep freebsd-client > /dev/null
if [ ! -e $P{ZPATH}/freebsd-client ]; then
	zfs create ${ZPOOL}/${ZSTOREVOL}/freebsd-client
	zfs mount ${ZPOOL}/${ZSTOREVOL}/freebsd-client
fi

# Set up a disk for a virtual machine setup
truncate -s 20G ${ZPATH}/freebsd-client/disk.img

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-client

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
TAP=$(ifconfig tap create)

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-client0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 2,nvme,${ZPATH}/freebsd-client/disk.img \
	-s 3,lpc \
	-s 4,virtio-net,${TAP},mac=00:00:00:ff:ff:03 \
	-s 5,ahci-cd,${ZPATH}/freebsd.iso \
	freebsd-client &

PID=$!

# tap10001 was created now
ifconfig ${TAP} name client0
ifconfig ${SWITCHNAME} addm client0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-client

ifconfig client0 destroy
