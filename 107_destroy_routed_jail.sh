#!/bin/sh

#
# Remove a routed jail
# and place its IP back into config.net
#

set -x

if [ ! -e config.sh ]; then
    echo Missing main jail configuration file.
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

# get the host ip from the jail.conf file
HOSTIP=$(cat /etc/jail.conf.d/${JAILNAME}.conf | grep hostip | awk -F= '{print $2}' | sed 's@[";]@@g' | awk -F. '{print $4}')
sed -i '' "1i\\
${HOSTIP}
" config.net

# remove and rebuild dhcpd config
rm /usr/local/etc/dhcpd/${HOSTIP}.conf
cp /usr/local/etc/dhcpd.conf.bridged /usr/local/etc/dhcpd.conf
cat /usr/local/etc/dhcpd/* >> /usr/local/etc/dhcpd.conf
service isc-dhcpd restart

# make sure that the epair interface is gone too
ifconfig ${JAILNAME}0 destroy > /dev/null 2>&1

rm -f /etc/jail.conf.d/${JAILNAME}.conf
rm ${ZPATH}/${JAILNAME}.fstab

# remove jail from activation list
sysrc jail_list-="${JAILNAME}"
