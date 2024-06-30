#!/bin/sh

set -x

# source configuration we started
if [ -e config.sh ]; then
    . ./config.sh
fi

# check for bridge
ifconfig vmswitch >> /dev/null

if [ "$?" != "0" ]; then
    ./06_setup_vmbridge.sh
fi

# create a ramdisk for backing storage
DISK=$(mdconfig -t malloc -s 8G -o reserve)

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-memdisk

# We create a tap
NET=$(ifconfig tap create)

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-memdisk0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 2,nvme,/dev/${DISK} \
	-s 3,lpc \
	-s 4,virtio-net,${NET},mac=00:00:00:ff:ff:02 \
	-s 5,ahci-cd,${ZPATH}/freebsd.iso \
	freebsd-memdisk &

PID=$!

# tap was created now
ifconfig ${NET} name mem0
ifconfig ${SWITCHNAME} addm mem0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-memdisk

ifconfig mem0 destroy
