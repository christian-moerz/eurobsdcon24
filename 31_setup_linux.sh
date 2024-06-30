#!/bin/sh

set -x

# source configuration we started
if [ -e config.sh ]; then
    . ./config.sh
fi

. ./utils.sh

NAME=linux
DISK=${NAME}
#IP=10.10.10.42
IP=0.0.0.0

# check for bridge
ifconfig vmswitch >> /dev/null

if [ "$?" != "0" ]; then
    ./06_setup_vmbridge.sh
fi

ensure_zfs ${ZPOOL}/${ZSTOREVOL}/${DISK}

# Set up a disk for a virtual machine setup
truncate -s 20G ${ZPATH}/${DISK}/disk.img

# create uefi vars file
cp /usr/local/share/uefi-firmware/BHYVE_UEFI_VARS.fd ${ZPATH}/${DISK}/vars.fd

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
    -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI_CODE.fd,${ZPATH}/${DISK}/vars.fd \
    -m 2G \
    -p 0:0 -p 1:1 \
    -s 0,hostbridge \
    -s 2,nvme,${ZPATH}/${DISK}/disk.img \
    -s 3,lpc \
    -s 4,virtio-net,${TAP},mac=00:00:00:ff:ff:02 \
    -s 5,fbuf,tcp=${IP}:5900,w=1600,h=900,password=secret,wait \
    -s 6,ahci-cd,${ZPATH}/debian.iso \
    ${NAME} &

PID=$!

# tap was created now
ifconfig ${TAP} name debian0
ifconfig vmswitch addm debian0

wait ${PID}

# Destroy the previously created vm
bhyvectl --destroy --vm=${NAME}

ifconfig debian0 destroy
