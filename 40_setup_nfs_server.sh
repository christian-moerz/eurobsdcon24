#!/bin/sh

set -x

if [ -e config.sh ]; then
	. ./config.sh
fi
ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labjails}
SWITCHNAME=${SWITCHNAME:=vmswitch}

ifconfig ${SWITCHNAME} > /dev/null 2>&1

if [ "0" != "$?" ]; then
    # run switch setup
    ./06_setup_vmbridge.sh
fi


# remove 10.193.167.2 from dhcp range
# because we use that as static ip for
# our nfs server

# make sure we are not running the nfs server ip in the dynamic range
sed -i '' 's@range 10.193.167.2 10.193.167.100;@range 10.193.167.3 10.193.167.100;@' /usr/local/etc/dhcpd.conf
service dhcpd enable
service dhcpd restart

# create a zfs volume if it does not exist
mount | grep freebsd-nfs > /dev/null
if [ ! -e ${ZPATH}/freebsd-nfs ]; then
	zfs create ${ZPOOL}/${ZSTOREVOL}/freebsd-nfs
	zfs mount ${ZPOOL}/${ZSTOREVOL}/freebsd-nfs
fi

# Set up a disk for a virtual machine setup
truncate -s 20G ${ZPATH}/freebsd-nfs/disk.img

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-nfs

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
TAP=$(ifconfig tap create)

# Start up a bhyve virtual machine with a local network interface
# add a user "chris" to be able to copy ssh key later on!
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-nfs0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 2,nvme,${ZPATH}/freebsd-nfs/disk.img \
	-s 3,lpc \
	-s 4,virtio-net,${TAP},mac=00:00:00:ff:ff:02 \
	-s 5,ahci-cd,${ZPATH}/freebsd.iso \
	freebsd-nfs &

PID=$!

# tap10001 was created now
ifconfig ${TAP} name nfs0
ifconfig ${SWITCHNAME} addm nfs0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-nfs

ifconfig nfs0 destroy
