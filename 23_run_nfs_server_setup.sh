#!/bin/sh

set -x

USERNAME=chris

# Generate a ssh keypair
mkdir .ssh
ssh-keygen -f .ssh/id_ecdsa -t ecdsa

# mount the disk and place it into ${USER} user directory
# this will not work, if we are running inside a jail!
DISKIMG=$(mdconfig -t vnode -f /labs/freebsd-nfs/disk.img)
ls /dev/md*
mount /dev/${DISKIMG}p2 /mnt
mkdir /mnt/home/${USER}/.ssh
cp .ssh/id_ecdsa.pub /mnt/home/${USER}s/.ssh/authorized_keys
chown -R 1001:1001 /mnt/home/${USER}/.ssh
chmod 750 /mnt/home/${USER}/.ssh
chmod 600 /mnt/home/${USER}/.ssh/authorized_keys
umount /mnt

mdconfig -d -u ${DISKIMG}

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
	freebsd-nfs &

PID=$!

# tap0 was created for nfs
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
