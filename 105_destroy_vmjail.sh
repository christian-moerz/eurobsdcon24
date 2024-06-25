#!/bin/sh

#
# Removes a jail again
#

if [ ! -e config.sh ]; then
    echo Missing mail jail configuration file.
    exit 1
fi

. ./config.sh
. ./utils.sh

JAILNAME=$1

if [ "" == "${JAILNAME}" ]; then
    echo Missing jail name argument.
    exit 2
fi

if [ ! -e ${ZPATH}/${JAILNAME} ]; then
    echo No such jail: ${JAILNAME}
    exit 2
fi

service jail onestop ${JAILNAME}

zfs destroy -f ${ZPOOL}/${ZSTOREVOL}/${JAILNAME}

rm -f /etc/jail.conf.d/${JAILNAME}.conf

# remove jail from activation list
sysrc jail_list-="${JAILNAME}"
