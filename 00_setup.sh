#!/bin/sh

# Use 101 script to set up lab environment first
# this should be run inside a main jail

# Initial download and setup script for bhyve 100 class
# We are working jail "lab" with this.

set -x

MYJID=$(sysctl -n security.jail.jailed)

if [ "0" == "${MYJID}" ]; then
    echo Running outside. Watch out.
    exit 1
fi

. ./utils.sh

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
	fetch -o ${ZPATH}/debian.iso http://debian.anexia.at/debian-cd/12.5.0/amd64/iso-dvd/debian-12.5.0-amd64-DVD-1.iso
fi

