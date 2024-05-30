#!/bin/sh

service vm stop
service vm disable

sysrc -x vm_enable
sysrc -x vm_dir

# Clean up after vm-bhyve
pkg remove -y vm-bhyve

rm -fr /labs/.iso
rm -fr /labs/.config
rm -fr /labs/.img
rm -fr /labs/.templates

zfs destroy zroot/labjails/freebsd/disk0
zfs destroy zroot/labjails/freebsd

rm -fr /labs/freebsd

