#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

# remove bmd
pkg remove -y bmd

rm -f /usr/local/etc/bmd.conf

# remove zfs volumes
zfs destroy ${ZPOOL}/${ZSTOREVOL}/vms/freebsd
zfs destroy ${ZPOOL}/${ZSTOREVOL}/vms

# remove bridge
./14_cleanup_for_pkgmgrs.sh

sysrc -x bmd_enable
