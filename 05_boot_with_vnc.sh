#!/bin/sh

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-vm

# Start up a bhyve virtual machine with a local network interface
# and a vnc console; this will probably need modifying loader.conf
# to set back to regular console or having to switch manually
# at boot; so we add a wait option to be able to connect properly
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-vm0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 1,ahci-cd,/labs/freebsd.iso \
	-s 2,nvme,/labs/freebsd-vm/disk.img \
	-s 3,lpc \
	-s 4,fbuf,tcp=127.0.0.1:5900,w=1600,h=900,password=secret,wait \
	-s 5,xhci,tablet \
	freebsd-vm

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-vm