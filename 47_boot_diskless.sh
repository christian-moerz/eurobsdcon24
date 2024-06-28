#!/bin/sh

set -x

if [ -e config.sh ]; then
    . ./config.sh
fi

SWITCHIP=${SWITCHIP:=10.193.167.1}
SUBNET=${SUBNET:=255.255.255.0}
DOMAINNAME=${DOMAINNAME:=bsd}
NETWORK=${NETWORK:=10.193.167.0}
BROADCAST=${BROADCAST:=10.193.167.255}
SWITCHNAME=${SWITCHNAME:=vmswitch}

#pkg install -y ipxe

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-diskless

# We create a tap
TAP=$(ifconfig tap create)

#	-s 5,ahci-cd,/usr/local/share/ipxe/ipxe.iso \

# Run without local disk
bhyve \
	-H \
	-c 2 \
	-D \
	-l com1,/dev/nmdmfreebsd-diskless0A \
	-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
	-m 2G \
	-s 0,hostbridge \
	-s 3,lpc \
	-s 4,virtio-net,${TAP},mac=00:00:00:ff:ff:03 \
	freebsd-diskless &

PID=$!

# tap was created now
ifconfig ${TAP} name diskless0
ifconfig ${SWITCHNAME} addm diskless0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-diskless

ifconfig diskless0 destroy
