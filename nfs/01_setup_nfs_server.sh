#!/bin/sh

# Sets up NFS server configuration

mkdir /nfs
echo /nfs -network=10.193.167.0/24 > /etc/exports
echo 'V4: /nfs' >> /etc/exports

sysrc nfs_server_enable=YES
sysrc nfsd_enable=YES
sysrc rpcbind_enable=YES
sysrc mountd_enable=YES
service nfsd start

# set up root
mkdir /nfs/vm01
if [ ! -e base.txz ]; then
fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
fi
tar -C /nfs/vm01 -xvf base.txz
tar -C /nfs/vm01 -xvf kernel.txz

RC=/nfs/vm01/etc/rc.conf
sysrc -f ${RC} hostname=vm01
sysrc -f ${RC} ifconfig_vtnet0="UP DHCP"
sysrc -f ${RC} sshd_enable=YES
sysrc -f ${RC} sendmail_enable=NONE

