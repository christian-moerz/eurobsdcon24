#!/bin/sh

# clean up for vm managers
service stop dhcpd
pkg remove -y dhcpd
sysrc -x dhcpd_enable

ifconfig vmswitch destroy
sysrc -x ifconfig_bridge0
sysrc -x create_args_bridge0
sysrc cloned_interfaces-="bridge0"
rm /usr/local/etc/dhcpd.conf


