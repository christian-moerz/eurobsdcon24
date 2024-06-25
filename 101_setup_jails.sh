#!/bin/sh

################################################################################

# This is run in the host environment to set up the lab

ZPOOL=zroot
ZVOL=lab
ZSTOREVOL=labdisk
JAILNAME=lab
# this is the mount point in host
LABPATH=/lab
# this is the mount path inside the jail!
ZPATH=/lab2
IP=10.10.10.41
SUBNET=255.255.255.252
JAILIP=10.10.10.42

PWD=$(pwd)

################################################################################

if [ -e config.sh ]; then
    echo config.sh of previous install exists. Remove first.
    exit 1
fi

. ./utils.sh

# set up zfs volume
ensure_zfs ${ZPOOL}/${ZVOL}
zfs set mountpoint=${LABPATH} ${ZPOOL}/${ZVOL}
# set up volume for base jail
ensure_zfs ${ZPOOL}/${ZVOL}/${JAILNAME}
# delegate management to jail
ensure_zfs ${ZPOOL}/${ZSTOREVOL}
zfs set jailed=on ${ZPOOL}/${ZSTOREVOL}

ETC=/etc/jail.conf.d/${JAILNAME}.conf
cp jail.conf ${ETC}

# download kernel and base
ensure_lab_download base.txz ${BASE}
ensure_lab_download kernel.txz ${KERNEL}
ensure_lab_download freebsd.iso ${ISO}

# extract base into volume
if [ ! -e ${LABPATH}/${JAILNAME}/bin ]; then
    tar -C ${LABPATH}/${JAILNAME} -xvf ${LABPATH}/base.txz
fi
mkdir -p ${LABPATH}/${JAILNAME}/root/eurobsdcon

# set up rc.local to ensure zfs mounting
# inside main jail
cat >> ${LABPATH}/${JAILNAME}/etc/rc.local <<EOF
#!/bin/sh
zfs mount -a
EOF
chmod 755 ${LABPATH}/${JAILNAME}/etc/rc.local

# install resolv.conf into main jail
cp /etc/resolv.conf ${LABPATH}/${JAILNAME}/etc
RC=${LABPATH}/${JAILNAME}/etc/rc.conf
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
sed -i '' "s@ZPATH@${LABPATH}@g" ${ETC}
sed -i '' "s@ZSTOREVOL@${ZSTOREVOL}@g" ${ETC}

# install devfs rules for jails, which allows
# use of vmm
if [ -e /etc/devfs.rules ]; then
    cp /etc/devfs.rules ${LABPATH}/devfs.rules.bak
fi
cp devfs.rules /etc/devfs.rules
service devfs restart

# copy mk-epair into jail, because we will use
# that for sub jail setup
cp mk-epair.sh ${LABPATH}
# install jail template file
cp jail.template /etc/jail.conf.d/${JAILNAME}.template
# we replace ZPATH with LABPATH for the main jail
sed -i '' "s@ZPATH@${LABPATH}@g" /etc/jail.conf.d/${JAILNAME}.template

# add fstab file for our main jail
FSTAB=${LABPATH}/${JAILNAME}.fstab
cp fstab ${FSTAB}
sed -i '' "s@ZPATH@${LABPATH}@g" ${FSTAB}
sed -i '' "s@MOUNTPATH@${PWD}@g" ${FSTAB}
sed -i '' "s@JAILNAME@${JAILNAME}@g" ${FSTAB}

# transfer base and kernel to jail as well
cp ${LABPATH}/base.txz ${LABPATH}/${JAILNAME}/root
cp ${LABPATH}/kernel.txz ${LABPATH}/${JAILNAME}/root

# store information into config.sh
cat > config.sh <<EOF
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
ZVOL=${ZVOL}
JAILNAME=${JAILNAME}
ZPATH=${ZPATH}
LABPATH=${LABPATH}
EOF

# we enable resource accounting in kernel
# changing this requires a reboot
echo "kern.racct.enable=1" >> /boot/loader.conf

# set up resource accounting ruleset
cat > /etc/rctl.conf <<EOF
jail:${JAILNAME}:pcpu:deny=50
EOF

service rctl enable
service rctl start

# start the jail
service jail onestart ${JAILNAME}
