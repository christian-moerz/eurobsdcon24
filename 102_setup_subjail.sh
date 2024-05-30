#!/bin/sh

################################################################################

ZPOOL=zroot
ZSTOREVOL=labdisk

# this ZPATH is inside the base jail!
ZPATH=/lab

################################################################################

# set up sub jail base
zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZSTOREVOL}

# install into scripts into lab environment
mv /root/base.txz ${ZPATH}/
mv /root/kernel.txz ${ZPATH}/
cp mk-epair.sh ${ZPATH}/
chmod 755 ${ZPATH}/mk-epair.sh

# write configuration into config file
cat >> config.sh <<EOF
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
ZPATH=${ZPATH}
EOF
