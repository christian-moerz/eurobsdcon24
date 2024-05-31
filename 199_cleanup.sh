#!/bin/sh

# Clean up and remove jail and work scripts
# This script is run in the host environment

################################################################################

#ZPOOL=zroot
#ZSTOREVOL=labdisk
#ZVOL=lab
#JAILNAME=lab
#ZPATH=/lab2

# load from config.sh
. ./config.sh

################################################################################

service jail onestop ${JAILNAME} > /dev/null 2>&1

rm -f /etc/jail.conf.d/${JAILNAME}.template
rm -f /etc/jail.conf.d/${JAILNAME}.conf

if [ -e ${ZPATH}/devfs.rules.bak ]; then
    mv ${ZPATH}/devfs.rules.bak /etc/devfs.rules
    service devfs restart
fi

echo Destroying ${ZPOOL}/${ZVOL} and ${ZPOOL}/${ZSTOREVOL} - continue?
read SURE

zfs destroy -f -r ${ZPOOL}/${ZVOL}
zfs destroy -f -r ${ZPOOL}/${ZSTOREVOL}
