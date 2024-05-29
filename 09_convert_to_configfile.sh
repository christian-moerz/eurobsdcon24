#!/bin/sh

set -x

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
	-s 4,virtio-net,tap10001,mac=00:00:00:ff:ff:02 \
	-o config.dump=1 \
	freebsd-vm > freebsd-vm.conf

# Output config file
cat freebsd-vm.conf

# Notice the config.dump=1 option that needs removing
sed -i '' '/config\.dump/d' freebsd-vm.conf

# Output updated config file
cat freebsd-vm.conf

