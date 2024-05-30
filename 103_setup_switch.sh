#!/bin/sh

# we set up a vm switch

# source configuration we started
. ./config.sh

SWITCHIP=10.193.167.1
SUBNET=255.255.255.0
DOMAINNAME=bsd
NETWORK=10.193.167.0
BROADCAST=10.193.167.255
SWITCHNAME=switch0

IPRANGE_START=10.193.167.33
IPRANGE_STOP=10.193.167.62

DNS=$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')

pkg install -y dhcpd

sysrc ifconfig_bridge0="inet ${SWITCHIP} netmask ${SUBNET} name ${SWITCHNAME}"
sysrc create_args_bridge0="ether 00:00:00:ff:ff:01"
sysrc cloned_interfaces+="bridge0"

service dhcpd enable

# extend configuration
cat >> config.sh <<EOF
SWITCHIP=${SWITCHIP}
SUBNET=${SUBNET}
DOMAINNAME=${DOMAINNAME}
NETWORK=${NETWORK}
BROADCAST=${BROADCAST}
SWITCHNAME=${SWITCHNAME}
DNS=${DNS}
EOF

# write dhcpd config
cat > /usr/local/etc/dhcpd.conf <<EOF
option domain-name "${DOMAINNAME}";
option domain-name-servers ${DNS};

option subnet-mask ${SUBNET};
default-lease-time 600;
max-lease-time 7200;

subnet ${NETWORK} netmask ${SUBNET} {
       range ${IPRANGE_START} ${IPRANGE_STOP};
       option broadcast-address ${BROADCAST};
       option routers ${SWITCHIP};
}
EOF

ifconfig bridge0 create
ifconfig ether 00:00:00:ff:ff:01
ifconfig bridge0 inet ${SWITCHIP} netmask ${SUBNET}
ifconfig bridge0 name ${SWITCHNAME}

service dhcpd start

