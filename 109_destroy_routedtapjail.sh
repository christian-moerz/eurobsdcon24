#!/bin/sh

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

# read out jail ip
HOSTIP=$(cat /etc/jail.conf.d/${JAILNAME}.conf | grep hostip | awk -F= '{print $2}' | sed 's@[";]@@g' | awk -F. '{print $4}')

# remove dhcp configuration
rm /usr/local/etc/dhcpd/${HOSTIP}.conf
cp /usr/local/etc/dhcpd.conf.bridged /usr/local/etc/dhcpd.conf
cat /usr/local/etc/dhcpd/* >> /usr/local/etc/dhcpd.conf
service isc-dhcpd restart

# remove interface creation
IFACE=$(sysrc -n jail_${JAILNAME}_iface)
sysrc -x jail_${JAILNAME}_iface
ifconfig ${JAILNAME}0 destroy
sysrc -x ifconfig_${IFACE}
sysrc cloned_interfaces-=${IFACE}

zfs destroy -f ${ZPOOL}/${ZSTOREVOL}/${JAILNAME}

rm -f /etc/jail.conf.d/${JAILNAME}.conf
rm ${ZPATH}/${JAILNAME}.fstab

# remove jail from activation list
sysrc jail_list-="${JAILNAME}"
