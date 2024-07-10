#!/bin/sh

# Needs to run on unbound again after running 301_setup script

install_key()
{
    if [ -e $1.lab.dns ]; then
	cat $1.lab.dns >> /usr/local/etc/unbound/$1.zone
	service unbound reload
    fi
}

install_key ny-central
