#!/bin/sh

# prepares network environment in main jail
# sets up a routed switch network
# this is run inside the main jail

# we set up a vm switch
set -x

# source configuration we started
if [ -e config.sh ]; then
    . ./config.sh
fi

# network configuration for our lab environment
# with sub jails and vms going in there
SWITCHIP=${SWITCHIP:=10.193.167.1}
SUBNET=${SUBNET:=255.255.255.0}
DOMAINNAME=${DOMAINNAME:=bsd}
NETWORK=${NETWORK:=10.193.167.0}
BROADCAST=${BROADCAST:=10.193.167.255}
SWITCHNAME=${SWITCHNAME:=vmswitch}

# add network configuration to config.sh
cat >> config.sh <<EOF
SWITCHIP=${SWITCHIP}
SUBNET=${SUBNET}
DOMAINNAME=${DOMAINNAME}
NETWORK=${NETWORK}
BROADCAST=${BROADCAST}
SWITCHNAME=${SWITCHNAME}
EOF

# ip range for dhcp server
IPRANGE_START=${IPRANGE_START:=10.193.167.33}
IPRANGE_STOP=${IPRANGE_STOP:=10.193.167.62}

# get dns server from main jail
DNS=$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')

# pkg install -y dhcpd
# Installing ISC dhcp server instead of OpenBSD one
pkg install -y isc-dhcp44-server

# add network config into rc.conf so it is started
# when the main jail starts
sysrc ifconfig_bridge0="inet ${SWITCHIP} netmask ${SUBNET} name ${SWITCHNAME}"
sysrc create_args_bridge0="ether 00:00:00:ff:ff:01"
sysrc cloned_interfaces+="bridge0"

# enable dhcp server
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

# replace switch name in jail.conf template
TEMPLATE=/etc/jail.conf.d/jail.template
sed -i '' "s@SWITCHNAME@${SWITCHNAME}@g" ${TEMPLATE}

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

# do ad hoc bridge creation so we do not
# need to restart the jail
ifconfig bridge0 create
ifconfig bridge0 ether 00:00:00:ff:ff:01
ifconfig bridge0 inet ${SWITCHIP} netmask ${SUBNET}
ifconfig bridge0 name ${SWITCHNAME}

# start the dhcp server
service isc-dhcpd start

