#!/bin/sh

set -x

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-vm

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-vm0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 2,nvme,/labs/freebsd-vm/disk.img \
	-s 3,lpc \
	-s 4,virtio-net,valelab:2,mac=00:00:00:ff:ff:02 \
	freebsd-vm &

PID=$!

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-vm

ifconfig vm0 destroy
