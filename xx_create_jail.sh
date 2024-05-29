#!/bin/sh

ZROOT=zroot/labjails/hierboot

# create a jail environment that we can boot with bhyve
zfs create ${ZROOT}

tar -C /labs/hierboot -xvf /labs/base.txz
tar -C /labs/hierboot -xvf /labs/kernel.txz

RCCONF=/labs/hierboot/etc/rc.conf

sysrc -f ${RCCONF} hostname=hierboot
sysrc -f ${RCCONF} ifconfig_vtnet0="UP DHCP"
sysrc -f ${RCCONF} sendmail_enable=NONE
cp /etc/resolv.conf /labs/hierboot/etc/

