#!/bin/sh

# set up nfs client
sysrc mountd_enable=YES
sysrc nfsd_enable=YES
sysrc rpcbind_enable=YES

echo "10.193.167.2:/nfs /nfs nfs rw 0 0" >> /etc/fstab

mkdir /nfs
mount /nfs

pkg install -y git
git clone -b releng/14.0 --depth 1 https://github.com/freebsd/freebsd-src /usr/src
git clone https://github.com/stblassitude/boot_root_nfs
cd boot_root_nfs
sed -i '' '/NO_MAN=/d' Makefile
touch boot_root_nfs.1
make
# retrieve the NFS handle
./boot_root_nfs 10.193.167.2:/nfs /

