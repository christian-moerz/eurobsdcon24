#!/bin/sh

# install bmd
pkg install -y bmd

zfs create zroot/labjails/vms

# Install configuration file
cp bmd.conf /usr/local/etc/

service bmd enable
service bmd start

# We need to set up our own bridge0
# that is not handled by bmd
ifconfig bridge0 create

# Set up a freebsd guest

