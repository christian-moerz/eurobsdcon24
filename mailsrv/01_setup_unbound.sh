#!/bin/sh

#
# Script running on unbound server to get DNS going
#

pkg install -y unbound doas

cat <<EOF > /usr/local/etc/doas.conf
permit nopass lab
EOF

# then set up local zone
mkdir -p /usr/local/etc/unbound
mv unbound.conf /usr/local/etc/unbound/unbound.conf
mv nycentral.zone /usr/local/etc/unbound/ny-central.lab.zone
mv eurobsdcon.zone /usr/local/etc/unbound/eurobsdcon.lab.zone

DNS=$(cat /etc/resolv.conf | grep nameserver | head -1 | awk '{print $2}')

sed -i '' "s@DNSSERVER@${DNS}@g" /usr/local/etc/unbound/unbound.conf

# Update resolver
echo "nameserver localhost" > /etc/resolv.conf

service unbound enable
service unbound start
