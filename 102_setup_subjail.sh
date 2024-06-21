#!/bin/sh

################################################################################

# sets up a sub jail
# this is run in the main jail

if [ -e config.sh ]; then
	. ./config.sh
fi

ZPATH=${ZPATH:=/lab2}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labdisk}

################################################################################

# set up sub jail base
zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZSTOREVOL}

# install into scripts into lab environment
if [ -e /root/base.txz ]; then
    mv /root/base.txz ${ZPATH}/
    mv /root/kernel.txz ${ZPATH}/
    cp mk-epair.sh ${ZPATH}/
    chmod 755 ${ZPATH}/mk-epair.sh
fi

# write configuration into config file
cat >> config.sh <<EOF
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
ZPATH=${ZPATH}
EOF
