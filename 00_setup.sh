#!/bin/sh

# Use 101 script to set up lab environment first
# this should be run inside a main jail

# Initial download and setup script for bhyve 100 class
# We are working jail "lab" with this.

set -x

. ./utils.sh

ensure_jailed

if [ -e config.sh ]; then
	. ./config.sh
fi

ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labdisk}

cat >> config.sh <<EOF
ZPATH=${ZPATH}
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
EOF

clean_config

zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZSTOREVOL}
zfs mount ${ZPOOL}/${ZSTOREVOL}

# Get current DNS server from resolv.conf
DNS=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}')

# Copy dhcpd.conf.sample
cp dhcpd.conf.sample dhcpd.conf
sed -i '' "s@8.8.8.8@${DNS}@" dhcpd.conf

# Download base and kernel files for later use
ensure_core_download base.txz ${BASE}
ensure_core_download kernel.txz ${KERNEL}
ensure_core_download freebsd.iso ${ISO}

if [ ! -e ${ZPATH}/debian.iso ]; then
	if [ -e debian.iso ]; then
		cp debian.iso ${ZPATH}/debian.iso
	else
		fetch -o ${ZPATH}/debian.iso https://gemmei.ftp.acc.umu.se/debian-cd/current/amd64/iso-cd/debian-12.6.0-amd64-netinst.iso
	fi
fi

if [ -e kernel.txz ]; then
	tar -C / -xvf kernel.txz
fi
