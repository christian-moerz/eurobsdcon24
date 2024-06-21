#!/bin/sh

#
# This script creates a sub jail for a bhyve guest
#
# This script is run inside the main jail
#

if [ ! -e config.sh ]; then
    echo Missing main jail configuration file.
    exit 1
fi

. ./config.sh
. ./utils.sh

JAILNAME=$1

if [ "" == "${JAILNAME}" ]; then
    echo Missing jail name argument.
    exit 2
fi

# ensure creation of jail zfs volume
ensure_zfs "${ZPOOL}/${ZSTOREVOL}/${JAILNAME}"

# extract base into new volume
if [ ! -e ${ZPATH}/${JAILNAME}/bin ]; then
    tar -C ${ZPATH}/${JAILNAME} -xvf ${ZPATH}/base.txz
fi

# install kernel as well
if [ ! -e ${ZPATH}/${JAILNAME}/boot/kernel/kernel ]; then
    tar -C ${ZPATH}/${JAILNAME} -xvf ${ZPATH}/kernel.txz
fi

# create a jail.conf.d file for this jail
cat > /etc/jail.conf.d/${JAILNAME}.conf <<EOF
${JAILNAME} {
	    host.hostname = \${name};
	    vnet;
	    children.max = 0;

	    allow.mount;
	    mount.devfs;
	    devfs_ruleset = 6;

	    allow.vmm = 1;

	    .include "/etc/jail.conf.d/jail.template";

	    securelevel = 3;

	    # we cannot sub-jail any zvols, so we need to
	    # work with whatever we have
}
EOF

# set rc.conf settings for sub jail
ETC=${ZPATH}/${JAILNAME}/etc/rc.conf
sysrc -f ${ETC} hostname=${JAILNAME}
sysrc -f ${ETC} sendmail_enable=NONE
sysrc -f ${ETC} ifconfig_bhyve0="DHCP UP"
sysrc -f ${ETC} syslogd_flags="-ss"

# create iso directory for nullfs mount
mkdir -p ${ZPATH}/${JAILNAME}/iso
touch ${ZPATH}/${JAILNAME}/iso/freebsd.iso
