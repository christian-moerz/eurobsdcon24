#!/bin/sh

set -x

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-diskless

bhyveload -e boot.netif.name=vtnet0 \
  -e boot.nfsroot.server=10.193.167.2 \
  -e boot.nfsroot.path=/nfs/vm01 \
  -e boot.netif.hwaddr=00:00:00:ff:ff:03 \
  -e boot.netif.ip=10.193.167.3 \
  -e boot.netif.netmask=255.255.255.0 \
  -m 2g \
  -h /nfs/vm01 \
  freebsd-diskless

bhyvectl --destroy --vm=freebsd-diskless
