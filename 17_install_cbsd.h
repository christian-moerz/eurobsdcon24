#!/bin/sh

set -x

if [ -e config.sh ]; then
	. ./config.sh
fi

# Don't follow along on this, unless you want to keep it afterwards

# Get cbsd set up
pkg install -y cbsd tmux

# Run setup / config
env workdir=${ZPATH} /usr/local/cbsd/sudoexec/initenv

# Run setup
cbsd bconstruct-tui

# Place ISO
cp /labs/freebsd.iso /labs/src/iso/cbsd-iso-FreeBSD-14.0-RELEASE-amd64-disc1.iso
