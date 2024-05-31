#!/bin/sh

set -x

if [ -e config.sh ]; then
	. ./config.sh
fi

ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labjails}

zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZSTOREVOL}
zfs mount ${ZPOOL}/${ZSTOREVOL}

# Get current DNS server from resolv.conf
DNS=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}')

# Copy dhcpd.conf.sample
cp dhcpd.conf.sample dhcpd.conf
sed -i '' "s@8.8.8.8@${DNS}@" dhcpd.conf

# Download base and kernel files for later use
if [ ! -e ${ZPATH}/base.txz ]; then
	fetch -o ${ZPATH}/base.txz http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
fi
if [ ! -e ${ZPATH}/kernel.txz ]; then
	fetch -o ${ZPATH}/kernel.txz http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
fi
if [ ! -e ${ZPATH}/freebsd.iso ]; then
	fetch -o ${ZPATH}/freebsd.iso http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso
fi
if [ ! -e ${ZPATH}/debian.iso ]; then
	fetch -o ${ZPATH}/debian.iso http://debian.anexia.at/debian-cd/12.5.0/amd64/iso-dvd/debian-12.5.0-amd64-DVD-1.iso
fi

