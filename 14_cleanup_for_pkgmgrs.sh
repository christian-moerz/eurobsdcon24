#!/bin/sh

set -x

# source configuration we started
if [ -e config.sh ]; then
    . ./config.sh
fi

SWITCHIP=${SWITCHIP:=10.193.167.1}
SUBNET=${SUBNET:=255.255.255.0}
DOMAINNAME=${DOMAINNAME:=bsd}
NETWORK=${NETWORK:=10.193.167.0}
BROADCAST=${BROADCAST:=10.193.167.255}
SWITCHNAME=${SWITCHNAME:=vmswitch}

# clean up for vm managers
service isc-dhcpd stop

pkg remove -y isc-dhcp44-server
sysrc -x dhcpd_enable

ifconfig ${SWITCHNAME} destroy
sysrc -x ifconfig_bridge0
sysrc -x create_args_bridge0
sysrc cloned_interfaces-="${SWITCHNAME}"
sysrc cloned_interfaces-="bridge0"
rm /usr/local/etc/dhcpd.conf

