#!/bin/sh

################################################################################

# sets up configuration for sub jails
# this is run in the main jail
# but does not actually create any jail yet

if [ -e config.sh ]; then
	. ./config.sh
fi

. ./utils.sh

ZPATH=${ZPATH:=/lab2}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labdisk}

################################################################################

# set up sub jail base
# zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZSTOREVOL}
ensure_zfs_mountpoint ${ZPATH} ${ZPOOL}/${ZSTOREVOL}

# install scripts and binaries into lab environment
if [ -e /root/base.txz ]; then
    mv /root/base.txz ${ZPATH}/
    mv /root/kernel.txz ${ZPATH}/
    cp mk-epair.sh ${ZPATH}/
    chmod 755 ${ZPATH}/mk-epair.sh
fi

# install subjail template
TEMPLATE=/etc/jail.conf.d/jail.template
cp subjail.template ${TEMPLATE}

# replace variables in template
sed -i '' "s@ZPATH@${ZPATH}@g" ${TEMPLATE}

# write configuration into config file
cat >> config.sh <<EOF
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
ZPATH=${ZPATH}
EOF

# make sure we only keep variables once
# instead of repeating them
clean_config
