#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

# install bmd
pkg install -y bmd

# Alternative: install from git - this cannot be undone!
# cd /root
# git clone https://github.com/yuichiro-naito/bmd
# cd bmd
# make
# make install

if [ ! -e /dev/zvol/${ZPOOL}/${ZSTOREVOL}/vms ]; then
    zfs create ${ZPOOL}/${ZSTOREVOL}/vms
    zfs set canmount=off ${ZPOOL}/${ZSTOREVOL}/vms
    zfs create -V 20G ${ZPOOL}/${ZSTOREVOL}/vms/freebsd
fi

# Install configuration file
cp bmd.conf /usr/local/etc/

# Set up a bridge with an ip address and dhcp
./06_setup_vmbridge.sh

service bmd enable
service bmd start

# Set up a freebsd guest
# done by creating disk and installing config
bmdctl install -c freebsd

bmdctl list

bmdctl boot freebsd

bmdctl list

