#!/bin/sh

set -x

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-diskless

bhyveload -e boot.netif.name=vtnet99 \
  -e boot.nfsroot.server=10.193.167.2
  -e boot.nfsroot.nfshandle=X0e465866a2398e4c0c000000cb3a01005e8a66f00000000000000000X
  -e boot.nfsroot.nfshandlelen=28
  -e boot.nfsroot.path=/nfs
  -e boot.netif.hwaddr=00:00:00:ff:ff:03 \
  -e boot.netif.ip=10.193.167.3 \
  -e boot.netif.netmask=255.255.255.0 \
  -m 2g \
  -h /nfs/vm01 \
  freebsd-diskless

# We create a tap
TAP=$(ifconfig tap create)

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
ifconfig vmswitch addm diskless0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-diskless

ifconfig diskless0 destroy
