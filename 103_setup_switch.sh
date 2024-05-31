#!/bin/sh

# we set up a vm switch
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

IPRANGE_START=${IPRANGE_START:=10.193.167.33}
IPRANGE_STOP=${IPRANGE_STOP:=10.193.167.62}

DNS=$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')

# pkg install -y dhcpd
# Installing ISC dhcp server instead of OpenBSD one
pkg install -y isc-dhcp44-server

sysrc ifconfig_bridge0="inet ${SWITCHIP} netmask ${SUBNET} name ${SWITCHNAME}"
sysrc create_args_bridge0="ether 00:00:00:ff:ff:01"
sysrc cloned_interfaces+="bridge0"

service isc-dhcpd enable

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

group diskless {
    next-server 10.193.167.2;
    filename "pxeboot";
    option root-path "10.193.167.2:/nfs/vm01/";

    host client {
	hardware ethernet 00:00:00:ff:ff:03;
	fixed-address 10.193.167.3;
    }
}

EOF

ifconfig bridge0 create
ifconfig bridge0 ether 00:00:00:ff:ff:01
ifconfig bridge0 inet ${SWITCHIP} netmask ${SUBNET}
ifconfig bridge0 name ${SWITCHNAME}

service isc-dhcpd start

