#!/bin/sh

set -x

NAME=linux
DISK=${NAME}
IP=10.10.10.38

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

# create a zfs volume if it does not exist
mount | grep ${DISK} > /dev/null
if [ ! -e /labs/${DISK} ]; then
	zfs create zroot/labjails/${DISK}
	zfs mount zroot/labjails/${DISK}
fi

# Set up a disk for a virtual machine setup
truncate -s 20G /labs/${DISK}/disk.img

# create uefi vars file
cp /usr/local/share/uefi-firmware/BHYVE_UEFI_VARS.fd /labs/${DISK}/vars.fd

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=${NAME}

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
TAP=$(ifconfig tap create)

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
    -AHP \
    -c 2 \
    -D \
    -l com1,/dev/nmdm${NAME}0A \
    -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd,/labs/${DISK}/vars.fd \
    -m 2G \
    -p 0:0 -p 1:1 \
    -s 0,hostbridge \
    -s 2,nvme,/labs/${DISK}/disk.img \
    -s 3,lpc \
    -s 4,virtio-net,${TAP},mac=00:00:00:ff:ff:02 \
    -s 5,fbuf,tcp=${IP}:5900,w=1600,h=900,password=secret,wait \
    -s 6,ahci-cd,/labs/debian.iso \
    ${NAME} &

PID=$!

# tap was created now
ifconfig ${TAP} name debian0
ifconfig vmswitch addm debian0

wait ${PID}

# Destroy the previously created vm
bhyvectl --destroy --vm=${NAME}

ifconfig debian0 destroy
