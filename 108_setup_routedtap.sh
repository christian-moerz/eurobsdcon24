#!/bin/sh

#
# Set up a routed jail with a non-vnet jail and a tap
# that is handed to the sub jail instead.
#

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
for NUM in 1 2 3 4; do
    PAIRDATA=$(dd if=/dev/random count=4| md5 | cut -b 1-2)
    MAC="${MAC}:${PAIRDATA}"
done

# get the first address from config.net
ROUTED=$(head -1 config.net)

# then we remove that entry from config.net
sed -i '' '1d' config.net

HOSTIP=${ROUTENET}.${ROUTED}
GUESTIP_TUPLET=$((ROUTED+1))
GUESTIP=${ROUTENET}.${GUESTIP_TUPLET}

NEXTIP=$((ROUTED+8))

# increment routetap
ROUTETAP_NEXT=$((ROUTETAP+1))
sed -i '' '/ROUTETAP=/d' config.sh
echo "ROUTETAP=${ROUTETAP_NEXT}" >> config.sh

# persist new tap interface
sysrc cloned_interfaces+="tap${ROUTETAP}"
sysrc ifconfig_tap${ROUTETAP}="inet ${HOSTIP} netmask 255.255.255.248 name ${JAILNAME}0 up"

# immediately create tap interface
ifconfig tap${ROUTETAP} create
ifconfig tap${ROUTETAP} inet ${HOSTIP} netmask 255.255.255.248 name ${JAILNAME}0 up

sysrc jail_${JAILNAME}_iface="tap${ROUTETAP}"

# create a jail.conf.d file for this jail
cat > /etc/jail.conf.d/${JAILNAME}.conf <<EOF
${JAILNAME} {
	    host.hostname = \${name};
	    children.max = 0;

	    \$hostip = "${HOSTIP}";

	    allow.mount;
	    mount.devfs;
	    devfs_ruleset = 6;

	    allow.vmm = 1;

	    .include "/etc/jail.conf.d/jail_routed_tap.template";

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
subnet ${ROUTENET}.${NETIP} netmask 255.255.255.248 {
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
sysrc -f ${ETC} syslogd_flags="-ss"

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

# start jail
service jail start ${JAILNAME}

# remove any previously set proxy settings
unset http_proxy
unset https_proxy

# install bhyve firmware
jexec ${JAILNAME} pkg install -y edk2-bhyve tmux

jexec ${JAILNAME} bhyvectl --create --vm=${JAILNAME}

if [ "0" != "$?" ]; then
    echo Bhyve failed.
    exit 1
fi

# then start installation
jexec ${JAILNAME} tmux new-session -d -s bhyve "bhyve \
      -H -c 2 -D -l com1,stdio \
      -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
      -m 2G \
      -s 0,hostbridge \
      -s 1,ahci-cd,/iso/quick.iso \
      -s 2,nvme,/vm/disk.img \
      -s 3,lpc \
      -s 4,virtio-net,tap${ROUTETAP} \
      ${JAILNAME}"

jexec ${JAILNAME} tmux attach-session -t bhyve

jexec ${JAILNAME} bhyvectl --destroy --vm=${JAILNAME}

# create bhyve start up script
mkdir -p ${ZPATH}/${JAILNAME}/usr/local/bin
cat > ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart <<EOF
#!/bin/sh

RESULT=0

while [ "0" == "\${RESULT}" ]; do
      bhyvectl --create --vm=${JAILNAME}
      /usr/bin/cpuset -l 1-8 \\
            /usr/sbin/bhyve \\
      		      -H -c 2 -D -l com1,stdio \\
		      -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \\
		      -m 2G \\
		      -s 0,hostbridge \\
 		      -s 2,nvme,/vm/disk.img \\
 		      -s 3,lpc \\
 		      -s 4,virtio-net,tap${ROUTETAP} \\
 		      ${JAILNAME}

      RESULT=\$?
      bhyvectl --destroy --vm=${JAILNAME}
done

EOF
chmod 755 ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart

# create bhyve rc.d script
mkdir -p ${ZPATH}/${JAILNAME}/usr/local/etc/rc.d
cat > ${ZPATH}/${JAILNAME}/usr/local/etc/rc.d/bhyve <<EOF
#!/bin/sh

# PROVIDE: bhyve
# REQUIRE: DAEMON
# BEFORE: login
# KEYWORD: shutdown

. /etc/rc.subr

name=bhyve
rcvar=bhyve_enable

start_cmd="vm_start"
stop_cmd="vm_stop"
pidfile="/var/run/\${name}.pid"

vm_start()
{
/usr/local/bin/tmux new-session -d -s bhyve "/usr/local/bin/bhyvestart"
}

do_kill()
{
	kill -0 \$1 > /dev/null 2>&1
}

vm_stop()
{
        pid=\$(ps ax | grep ${JAILNAME} | grep -v grep|awk '{print \$1}')
        echo -n "Shutting down... \${pid} "
        kill -TERM \${pid}
        while do_kill \${pid}; do
                echo -n '.'
                sleep 1
        done
        echo " done."
}

load_rc_config $name
run_rc_command "\$1"
EOF
chmod 755 ${ZPATH}/${JAILNAME}/usr/local/etc/rc.d/bhyve

# stop jail
service jail onestop ${JAILNAME}

# enable bhyve rc.d script
sysrc -f ${ETC} bhyve_enable=YES

# restart with rc.local startup
service jail onestart ${JAILNAME}

# add jail to activation list
sysrc jail_list+="${JAILNAME}"
