#!/bin/sh

# configure a bridge
sysrc cloned_interfaces+="epair0"
sysrc ifconfig_epair0a="inet 10.193.167.1 netmask 255.255.255.0 name vmswitch0 group vm-cable up"

ifconfig vmswitch0 > /dev/null
if [ "$?" != "0" ]; then
	ifconfig epair0 create
	ifconfig epair0a inet 10.193.167.1 netmask 255.255.255.0 name vmswitch0 group vm-cable up
	ifconfig epair0b up
fi

# make sure that local epair0b is plugged into vale switch valelab
valectl -h valelab:epair0b

# install dhcp server
pkg install -y dhcpd
cp dhcpd.conf /usr/local/etc
service dhcpd enable
service dhcpd start

