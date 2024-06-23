#!/bin/sh

################################################################################

# sets up configuration for sub jails
# this is run in the main jail
# but does not actually create any jail yet

if [ -e config.sh ]; then
	. ./config.sh
fi

. ./utils.sh

ensure_jailed

ZPATH=${ZPATH:=/lab2}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labdisk}

################################################################################

# set up sub jail base
# zfs set mountpoint=${ZPATH} ${ZPOOL}/${ZSTOREVOL}
ensure_zfs_mountpoint ${ZPATH} ${ZPOOL}/${ZSTOREVOL}

mkdir -p ${ZPATH}/iso

# install scripts and binaries into lab environment
ensure_core_download base.txz ${BASE}
ensure_core_download kernel.txz ${KERNEL}
ensure_core_download iso/freebsd.iso ${ISO}
install -m 755 mk-epair.sh ${ZPATH}

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

# install bhyve cleanup script
mkdir -p /usr/local/bin
cat >> /usr/local/bin/bhyveclean <<EOF
#!/bin/sh

if [ -e /dev/vmm/\$1 ]; then
   bhyvectl --destroy --vm=\$1
fi
EOF
chmod 755 /usr/local/bin/bhyveclean

# re-install pkg so we have a pkg package for
# later use in subjail
pkg install -y -f pkg

# make sure we only keep variables once
# instead of repeating them
clean_config
