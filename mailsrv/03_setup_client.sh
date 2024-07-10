#!/bin/sh

#
# Run on client to ready for client use
#

gen_user()
{
    id $1 > /dev/null 2>&1
    if [ "0" != "$?" ]; then
	pw user add $1 -m
	NEWPASS=$(echo $1.mail | openssl passwd -6 -stdin)
	chpass -p ${NEWPASS} $1
    fi
}

gen_user ny_central
gen_user eurobsdcon

# install a local mail client
pkg install -y alpine ca_root_nss

if [ ! -e /usr/local/etc/ssl/cert.pem.ca ]; then
    cp /usr/local/etc/ssl/cert.pem /usr/local/etc/ssl/cert.pem.ca
    cat ca.crt >> /usr/local/etc/ssl/cert.pem
    cat ca.crt >> /etc/ssl/cert.pem
fi
install -m 0444 ca.crt /usr/share/certs/trusted/NY_Central.pem
certctl trust ca.crt
openssl rehash /etc/ssl/certs
certctl rehash

echo Setup completed.
