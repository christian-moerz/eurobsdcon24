#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

# Use vm-bhyve for network setup
# set up switch
vm switch create -a ${SWITCHIP}/${SUBNET} ${SWITCHNAME}

# NAT is not supported
# vm switch nat vmswitch on

# Link the freebsd.iso in the .iso directory
ln -s ${ZPATH}/freebsd.iso ${ZPATH}/.iso/freebsd.iso

# Copy the template file to template dir
cp vm-bhyve.template ${ZPATH}/.templates/freebsd.conf

# create vm
vm create -t freebsd -s 20G -m 2G -c 2 freebsd

# troubleshooting:
# look into /labs/<vmname>/<vmname>.log
# we might be missing the bridge now after a reboot
# run to fix:
service vm enable
/usr/local/etc/rc.d/vm start

# install freebsd
vm install freebsd freebsd.iso

# wait for vm to initialize
sleep 3

# attach to console and complete installation
vm console freebsd

# then checkout /labs/freebsd
# also do zfs list and check the zvol structure

# use zfs configure <name>
# to manually edit configuration file

