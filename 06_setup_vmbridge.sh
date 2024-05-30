#!/bin/sh

# configure a bridge
sysrc cloned_interfaces+="bridge0"
sysrc ifconfig_bridge0="inet 10.193.167.1 netmask 255.255.255.0 name vmswitch group vm-switch up"
sysrc create_args_bridge0="ether 00:00:00:ff:ff:01"

ifconfig vmswitch >> /dev/null

if [ "$?" != "0" ]; then
	# start that bridge
	ifconfig bridge0 create
	ifconfig bridge0 inet 10.193.167.1 netmask 255.255.255.0 name vmswitch group vm-switch up
fi
ifconfig vmswitch ether 00:00:00:ff:ff:01 

# install dhcp server
pkg install -y dhcpd
cp dhcpd.conf /usr/local/etc
service dhcpd enable
service dhcpd start

