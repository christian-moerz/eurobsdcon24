#!/bin/sh

# Clean up and remove jail and work scripts

################################################################################

ZPOOL=zroot
ZVOL=lab
JAILNAME=lab
ZPATH=/lab2

################################################################################

service jail onestop ${JAILNAME} > /dev/null 2>&1

rm -f /etc/jail.conf.d/${JAILNAME}.template
rm -f /etc/jail.conf.d/${JAILNAME}.conf

if [ -e ${ZPATH}/devfs.rules.bak ]; then
    mv ${ZPATH}/devfs.rules.bak /etc/devfs.rules
    service devfs restart
fi

zfs destroy -r ${ZPOOL}/${ZVOL}
