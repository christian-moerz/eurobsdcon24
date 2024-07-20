#!/bin/sh

# Needs to run on unbound again after running 301_setup script

install_key()
{
    if [ -e $1.dns ]; then
	# make sure to remove any pre-existing keys
	sed -i '' '/_default/d' /usr/local/etc/unbound/$1.zone
	sed -i '' '/"p=/d' /usr/local/etc/unbound/$1.zone
	sed -i '' '/DKIM key/d' /usr/local/etc/unbound/$1.zone
	
	cat $1.dns >> /usr/local/etc/unbound/$1.zone
	service unbound reload
	echo "$1 DKIM key installed."
    fi
}

install_key ny-central.lab
install_key eurobsdcon.lab
