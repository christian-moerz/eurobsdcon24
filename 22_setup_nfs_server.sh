#!/bin/sh

set -x

# configure a bridge
sysrc cloned_interfaces+="bridge0"
sysrc ifconfig_bridge0="inet 10.193.167.1 netmask 255.255.255.0 name vmswitch group vm-switch up"
sysrc create_args_bridge0="ether 00:00:00:ff:ff:01"

ifconfig vmswitch >> /dev/null

if [ "$?" != "0" ]; then
        # start that bridge
        ifconfig bridge0 create
        ifconfig bridge0 inet 10.193.167.1 netmask 255.255.255.0 name vmswitch group vm-switch up
fi
ifconfig vmswitch ether 00:00:00:ff:ff:01 

# install dhcp server
pkg install -y dhcpd
cp dhcpd.conf /usr/local/etc

# remove 10.193.167.2 from dhcp range
# because we use that as static ip for
# our nfs server

sed -i '' 's@range 10.193.167.2 10.193.167.100;@range 10.193.167.3 10.193.167.100;@' /usr/local/etc/dhcpd.conf
service dhcpd enable
service dhcpd start

# create a zfs volume if it does not exist
mount | grep freebsd-nfs > /dev/null
if [ ! -e /labs/freebsd-nfs ]; then
	zfs create zroot/labjails/freebsd-nfs
	zfs mount zroot/labjails/freebsd-nfs
fi

# Set up a disk for a virtual machine setup
truncate -s 20G /labs/freebsd-nfs/disk.img

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-nfs

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
ifconfig tap0 create

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-nfs0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 2,nvme,/labs/freebsd-nfs/disk.img \
	-s 3,lpc \
	-s 4,virtio-net,tap0,mac=00:00:00:ff:ff:02 \
	-s 5,ahci-cd,/labs/freebsd.iso \
	freebsd-nfs &

PID=$!

# tap10001 was created now
ifconfig tap0 name nfs0
ifconfig vmswitch addm nfs0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-nfs

ifconfig nfs0 destroy
