#!/bin/sh

################################################################################

# This is run in the host environment to set up the lab

ZPOOL=zroot
ZVOL=lab
ZSTOREVOL=labdisk
JAILNAME=lab
ZPATH=/lab2
IP=10.10.10.41
SUBNET=255.255.255.252
JAILIP=10.10.10.42

BASE=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
KERNEL=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
ISO=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso
PWD=$(pwd)

################################################################################

. ./utils.sh

# set up zfs volume
ensure_zfs ${ZPOOL}/${ZVOL}
zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZVOL}
# set up volume for base jail
ensure_zfs ${ZPOOL}/${ZVOL}/${JAILNAME}
# delegate management to jail
ensure_zfs ${ZPOOL}/${ZSTOREVOL}
zfs set jailed=on ${ZPOOL}/${ZSTOREVOL}

ETC=/etc/jail.conf.d/${JAILNAME}.conf
cp jail.conf ${ETC}

# download kernel and base
if [ ! -e ${ZPATH}/base.txz ]; then
    fetch -o ${ZPATH}/base.txz ${BASE}
fi
if [ ! -e ${ZPATH}/kernel.txz ]; then
    fetch -o ${ZPATH}/kernel.txz ${KERNEL}
fi
# fetch -o ${ZPATH}/freebsd.iso ${ISO}

# extract base into volume
if [ ! -e ${ZPATH}/${JAILNAME}/bin ]; then
    tar -C ${ZPATH}/${JAILNAME} -xvf ${ZPATH}/base.txz
fi
mkdir -p ${ZPATH}/${JAILNAME}/root/eurobsdcon

# set up rc.local to ensure zfs mounting
# inside main jail
cat >> ${ZPATH}/${JAILNAME}/etc/rc.local <<EOF
#!/bin/sh
zfs mount -a
EOF
chmod 755 ${ZPATH}/${JAILNAME}/etc/rc.local

# install resolv.conf into main jail
cp /etc/resolv.conf ${ZPATH}/${JAILNAME}/etc
RC=${ZPATH}/${JAILNAME}/etc/rc.conf
# set main jail network config
sysrc -f ${RC} ifconfig_vtnet0="inet ${JAILIP} netmask ${SUBNET}"
sysrc -f ${RC} defaultrouter="${IP}"
# disable sendmail in main jail
sysrc -f ${RC} sendmail_eanble=NONE

# replace variables in jail.conf for main jail
sed -i '' "s@JAILNAME@${JAILNAME}@g" ${ETC}
sed -i '' "s@IP@${IP}@g" ${ETC}
sed -i '' "s@SUBNET@${SUBNET}@g" ${ETC}
sed -i '' "s@ZPOOL@${ZPOOL}@g" ${ETC}
sed -i '' "s@ZVOL@${ZVOL}@g" ${ETC}
sed -i '' "s@ZPATH@${ZPATH}@g" ${ETC}
sed -i '' "s@ZSTOREVOL@${ZSTOREVOL}@g" ${ETC}

# install devfs rules for jails, which allows
# use of vmm
if [ -e /etc/devfs.rules ]; then
    cp /etc/devfs.rules ${ZPATH}/devfs.rules.bak
fi
cp devfs.rules /etc/devfs.rules
service devfs restart

# copy mk-epair into jail, because we will use
# that for sub jail setup
cp mk-epair.sh ${ZPATH}
# install jail template file
cp jail.template /etc/jail.conf.d/${JAILNAME}.template
sed -i '' "s@ZPATH@${ZPATH}@g" /etc/jail.conf.d/${JAILNAME}.template

# add fstab file for our main jail
FSTAB=${ZPATH}/${JAILNAME}.fstab
cp fstab ${FSTAB}
sed -i '' "s@ZPATH@${ZPATH}@g" ${FSTAB}
sed -i '' "s@MOUNTPATH@${PWD}@g" ${FSTAB}
sed -i '' "s@JAILNAME@${JAILNAME}@g" ${FSTAB}

# transfer base and kernel to jail as well
cp ${ZPATH}/base.txz ${ZPATH}/${JAILNAME}/root
cp ${ZPATH}/kernel.txz ${ZPATH}/${JAILNAME}/root

# store information into config.sh
cat > config.sh <<EOF
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
ZVOL=${ZVOL}
JAILNAME=${JAILNAME}
ZPATH=${ZPATH}
EOF

# we enable resource accounting in kernel
# changing this requires a reboot
echo "kern.racct.enable=1" >> /boot/loader.conf
