#!/bin/sh

# Clean up and remove jail and work scripts
# This script is run in the host environment

################################################################################

#ZPOOL=zroot
#ZSTOREVOL=labdisk
#ZVOL=lab
#JAILNAME=lab
#ZPATH=/lab2

if [ ! -e config.sh ]; then
    echo Cannot clean up. Could not find config.sh
    exit 1
fi

# load from config.sh
. ./config.sh
. ./utils.sh

ensure_unjailed

################################################################################

# stop base jail
service jail onestop ${JAILNAME} > /dev/null 2>&1

# remove jail template faile
rm -f /etc/jail.conf.d/${JAILNAME}.template
# remove base jail config file
rm -f /etc/jail.conf.d/${JAILNAME}.conf

# reset original devfs rules
if [ -e ${ZPATH}/devfs.rules.bak ]; then
    mv ${ZPATH}/devfs.rules.bak /etc/devfs.rules
    service devfs restart
fi

# remove ractl kernel config from loader.conf
# reboot afterwards to disable
sed -i '' '/kern\.racct\.enable=1/d' /boot/loader.conf

# finally, we clean up config.sh and config.net
rm -f config.sh config.net

# make sure we have destroyed any remains
ifconfig vtnet0 destroy
bhyvectl --destroy --vm=client > /dev/null

echo Destroying ${ZPOOL}/${ZVOL} and ${ZPOOL}/${ZSTOREVOL} - continue?
read SURE

# delete zpool storage
zfs destroy -f -r ${ZPOOL}/${ZVOL}
zfs destroy -f -r ${ZPOOL}/${ZSTOREVOL}
