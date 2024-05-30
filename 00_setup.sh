#!/bin/sh

zfs set mountpoint=/labs zroot/labjails

# Get current DNS server from resolv.conf
DNS=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}')

# Copy dhcpd.conf.sample
cp dhcpd.conf.sample dhcpd.conf
sed -i '' "s@8.8.8.8@${DNS}@" dhcpd.conf

# Download base and kernel files for later use
if [ ! -e /labs/base.txz ]; then
	fetch -o /labs/base.txz http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
fi
if [ ! -e /labs/kernel.txz ]; then
	fetch -o /labs/kernel.txz http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
fi
if [ ! -e /labs/freebsd.iso ]; then
	fetch -o /labs/freebsd.iso http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso
fi

# make sure zfs volumes are mounted
zfs mount zroot/labjails
zfs mount zroot/labjails/freebsd-vm
