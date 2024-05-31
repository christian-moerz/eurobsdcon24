#!/bin/sh

set -x

# check for bridge
ifconfig vmswitch >> /dev/null

if [ "$?" != "0" ]; then
        # start that bridge
        ifconfig bridge0 create
        ifconfig bridge0 inet 10.193.167.1 netmask 255.255.255.0 name vmswitch group vm-switch up

	sysrc cloned_interfaces+="bridge0"
	sysrc ifconfig_bridge0="inet 10.193.167.1 netmask 255.255.255.0 name vmswitch group vm-switch up"
	sysrc create_args_bridge0="ether 00:00:00:ff:ff:01"

	# install dhcp server
	pkg install -y dhcpd
	cp dhcpd.conf /usr/local/etc
	service dhcpd enable
	service dhcpd start
fi

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
	-s 2,nvme,/dev/md0 \
	-s 3,lpc \
	-s 4,virtio-net,${NET},mac=00:00:00:ff:ff:02 \
	freebsd-memdisk &

PID=$!

# tap was created now
ifconfig ${NET} name mem0
ifconfig vmswitch addm mem0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-memdisk

ifconfig mem0 destroy
