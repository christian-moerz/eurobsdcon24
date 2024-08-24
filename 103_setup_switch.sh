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

. ./utils.sh

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
DNS=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{ print $2 }')

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

EOF
# create an "bridged" copy for any routed additions later on
cp /usr/local/etc/dhcpd.conf /usr/local/etc/dhcpd.conf.bridged

# do ad hoc bridge creation so we do not
# need to restart the jail
ifconfig bridge0 create
ifconfig bridge0 ether 00:00:00:ff:ff:01
ifconfig bridge0 inet ${SWITCHIP} netmask ${SUBNET}
ifconfig bridge0 name ${SWITCHNAME}

# start the dhcp server
service isc-dhcpd start

pkg install -y ipcalc

SUBMASK=$(ipcalc -nb ${NETWORK}/${SUBNET} | grep Netmask | awk -F= '{ print $2}')
SUBMASK=$(echo ${SUBMASK})

# enable a NAT firewall via pf
# that allows outbound traffic from our sub jails
cat > /etc/pf.conf <<EOF
extif="vtnet0"
switch="${SWITCHNAME}"

table <jailaddrs> { ${NETWORK}/${SUBMASK} ${ROUTENET}.0/24 }

nat on \$extif from <jailaddrs> to any -> (\$extif)

pass in on \$switch from <jailaddrs> to ! ${NETWORK}/${SUBMASK} tag jail_out
pass on \$extif from <jailaddrs> to ! ${NETWORK}/${SUBMASK} tagged jail_out
EOF

if [ "" == "${ROUTENET}" ]; then
    # remove incorrect network
    sed -i '' 's/ .0\/24//g' /etc/pf.conf
fi

service pf enable
service pf start

# enable IP forwarding
echo net.inet.ip.forwarding=1 >> /etc/sysctl.conf
service sysctl restart

clean_config
