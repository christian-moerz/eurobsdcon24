#!/bin/sh

# Install NAT ruleset and enable firewall
cp pf.conf /etc
service pf enable
service pf start

sysrc gateway_enable=YES
sysctl net.inet.ip.forwarding=1

