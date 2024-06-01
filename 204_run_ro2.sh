#!/bin/sh

set -x

if [ -e config.sh ]; then
	. ./config.sh
fi
ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labjails}
SWITCHNAME=${SWITCHNAME:=vmswitch}
VMNAME=ro2

if [ ! -e ${ZPATH}/freebsd-${VMNAME} ]; then
    zfs create ${ZPOOL}/${ZSTOREVOL}/freebsd-${VMNAME}
fi

if [ ! -e ${ZPATH}/freebsd-${VMNAME}/rw.img ]; then
    cp ${ZPATH}/freebsd-base/disk.img_rw.img ${ZPATH}/freebsd-${VMNAME}/rw.img
fi

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-${VMNAME}

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
TAP=$(ifconfig tap create)

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-${VMNAME}0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 3,virtio-blk,${ZPATH}/freebsd-base/disk.img_root.img \
	-s 4,lpc \
	-s 5,virtio-net,${TAP},mac=00:00:00:ff:ff:10 \
	-s 6,nvme,${ZPATH}/freebsd-${VMNAME}/rw.img \
	freebsd-${VMNAME} &

PID=$!

# tap0 was created for nfs
ifconfig ${TAP} name ${VMNAME}0
ifconfig ${SWITCHNAME} addm ${VMNAME}0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-${VMNAME}

ifconfig ${VMNAME}0 destroy
