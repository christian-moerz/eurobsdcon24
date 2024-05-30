#!/bin/sh

# remove bmd
pkg remove -y bmd
rm /usr/local/etc/bmd.conf

# remove zfs volumes
zfs destroy zroot/labjails/vms/freebsd
zfs destroy zroot/labjails/vms
