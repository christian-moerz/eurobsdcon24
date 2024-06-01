#!/bin/sh

# Sets up NFS server configuration

mkdir /nfs
echo /nfs /nfs/vm01 -maproot=chris -network=10.193.167.0/24 > /etc/exports
echo 'V4: /nfs' >> /etc/exports

sysrc nfs_server_enable=YES
sysrc nfsd_enable=YES
sysrc rpcbind_enable=YES
sysrc mountd_enable=YES
service nfsd start

echo Downloading core files - if this breaks, check proxy settings!

# set up root
mkdir -p /nfs/vm01
chown -R chris /nfs
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

################################################################################

# Set up tftp server for pxe boot

mkdir -p /var/tftpboot
ln -s /var/tftpboot /tftpboot
# enable tftp in inetd
sed -i '' 's@#tftp@tftp@g' /etc/inetd.conf
service inetd enable
service inetd start

# copy pxeboot to tftp
cp /boot/pxeboot /tftpboot
chmod 444 /tftpboot/pxeboot

################################################################################

# Fix pxeboot loader size
cd /usr/src
pkg install -y git
git clone --depth 1 -b releng/14.0 https://github.com/freebsd/freebsd-src /usr/src
cd /usr/src/stand
make WITHOUT_LOADER_ZFS=YES clean
make WITHOUT_LOADER_ZFS=YES all
make WITHOUT_LOADER_ZFS=YES install DESTDIR=/nfs/vm01

