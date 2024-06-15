#!/bin/sh

set -x

# source configuration we started
if [ -e config.sh ]; then
    . ./config.sh
fi

SWITCHNAME=${SWITCHNAME:=vmswitch}

# Install NAT ruleset and enable firewall
cp pf.conf /etc

sed -i '' "s@SWITCHNAME@${SWITCHNAME}@g" /etc/pf.conf

service pf enable
service pf start

sysrc gateway_enable=YES
sysctl net.inet.ip.forwarding=1

