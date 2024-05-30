#!/bin/sh

# create a vale switch a local device
valectl -n vmswitch

ifconfig vmswitch inet 10.193.167.1 netmask 255.255.255.0
ifconfig vmswitch ether 00:00:00:ff:ff:01

# install dhcp server
pkg install -y dhcpd
cp dhcpd.conf /usr/local/etc
service dhcpd enable
service dhcpd start

