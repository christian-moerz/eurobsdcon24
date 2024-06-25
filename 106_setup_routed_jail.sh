#!/bin/sh

# set up a routed vm jail instead of a bridged on
# for this, we get the routed environment from config.sh
# and create a new /29 network for our sub jail

set -x

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
# use caching in guest instead of host
zfs set primarycache=metadata ${ZPOOL}/${ZSTOREVOL}/${JAILNAME}

# extract base into new volume
if [ ! -e ${ZPATH}/${JAILNAME}/bin ]; then
    tar -C ${ZPATH}/${JAILNAME} -xf ${ZPATH}/base.txz
fi

# install kernel as well
if [ ! -e ${ZPATH}/${JAILNAME}/boot/kernel/kernel ]; then
    tar -C ${ZPATH}/${JAILNAME} -xf ${ZPATH}/kernel.txz
fi

# generate a random mac address
MAC="00:00"
IMAC="00:ff"
VMMAC="00:aa"
for NUM in 1 2 3 4; do
    PAIRDATA=$(dd if=/dev/random count=4| md5 | cut -b 1-2)
    MAC="${MAC}:${PAIRDATA}"
    IMAC="${IMAC}:${PAIRDATA}"
    VMMAC="${VMMAC}:${PAIRDATA}"
done

# get the first address from config.net
ROUTED=$(head -1 config.net)

# then we remove that entry from config.net
sed -i '' '1d' config.net

HOSTIP=${ROUTENET}.${ROUTED}
GUESTIP_TUPLET=$((ROUTED+1))
GUESTIP=${ROUTENET}.${GUESTIP_TUPLET}

# then updated config.sh
NEXTIP=$((ROUTED+8))
sed -i '' "/ROUTED=${ROUTED}/d" config.sh

# create a jail.conf.d file for this jail
cat > /etc/jail.conf.d/${JAILNAME}.conf <<EOF
${JAILNAME} {
	    host.hostname = \${name};
	    vnet;
	    children.max = 0;

	    \$mac = "${MAC}";
	    \$imac = "${IMAC}";
	    \$hostip = "${HOSTIP}";

	    allow.mount;
	    mount.devfs;
	    devfs_ruleset = 6;

	    allow.vmm = 1;

	    .include "/etc/jail.conf.d/jail_routed.template";

	    securelevel = 3;

	    # we cannot sub-jail any zvols, so we need to
	    # work with whatever we have
}
EOF

# add a dhcp rservation
mkdir -p /usr/local/etc/dhcpd
NETIP=$((ROUTED-1))
LASTIP=$((ROUTED+6))
BROADCAST=$((LASTIP+1))
cat > /usr/local/etc/dhcpd/${ROUTED}.conf <<EOF
subnet ${ROUTENET}.${NETIP} netmask 255.255.255.224 {
       range ${GUESTIP} ${ROUTENET}.${LASTIP};
       option broadcast-address ${ROUTENET}.${BROADCAST};
       option routers ${ROUTENET}.${ROUTED};
}
EOF

# then build a new dhcpd.conf
cp /usr/local/etc/dhcpd.conf.bridged /usr/local/etc/dhcpd.conf
cat /usr/local/etc/dhcpd/* >> /usr/local/etc/dhcpd.conf
service isc-dhcpd restart

# set rc.conf settings for sub jail
ETC=${ZPATH}/${JAILNAME}/etc/rc.conf
sysrc -f ${ETC} sendmail_enable=NONE
sysrc -f ${ETC} ifconfig_bhyve0="DHCP"
sysrc -f ${ETC} syslogd_flags="-ss"
sysrc -f ${ETC} cloned_interfaces="bridge0"
sysrc -f ${ETC} ifconfig_bridge0="addm bhyve0 up"

# create iso directory for nullfs mount
mkdir -p ${ZPATH}/${JAILNAME}/iso

# create vm directory
mkdir -p ${ZPATH}/${JAILNAME}/vm
# create vm disk image
truncate -s 20G ${ZPATH}/${JAILNAME}/vm/disk.img

# create fstab file
cat > ${ZPATH}/${JAILNAME}.fstab <<EOF
${ZPATH}/iso    ${ZPATH}/${JAILNAME}/iso nullfs ro 0 0
EOF

# install resolv.conf
cp /etc/resolv.conf ${ZPATH}/${JAILNAME}/etc

# start the jail
service jail onestart ${JAILNAME}

# remove any previously set proxy settings
unset http_proxy
unset https_proxy

# install bhyve firmware
jexec ${JAILNAME} pkg install -y edk2-bhyve tmux

service jail onestop ${JAILNAME}

