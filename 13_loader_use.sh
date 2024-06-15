#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

# make sure we have a kernel for use by bhyveload
if [ ! -e /boot/kernel/kernel ]; then
    tar -C / -xvf ${ZPATH}/kernel.txz
fi

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-vm

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
TAP=$(ifconfig tap create)

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyveload -m 2G -h / -c /dev/nmdmfreebsd-vm0A \
	  -e vfs.root.mountfrom=ufs:/dev/nda0p2 \
	  freebsd-vm

bhyve \
    -A \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-vm0A \
	-m 2G \
	-s 0,hostbridge \
	-s 2,nvme,${ZPATH}/freebsd-vm/disk.img \
	-s 3,lpc \
	-s 4,virtio-net,${TAP},mac=00:00:00:ff:ff:02 \
	freebsd-vm &

PID=$!

# tap10001 was created now
ifconfig ${TAP} name vm0
ifconfig vmswitch addm vm0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-vm

ifconfig vm0 destroy

