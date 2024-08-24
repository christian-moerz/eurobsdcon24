#!/bin/sh

# set -x

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

MEMORY=2G
ISO=quick.iso
DISKSIZE=20G

ensure_jailed

while getopts 'm:d:c:' opt; do
    case "$opt" in
	# use $OPTARG

	m)
	    MEMORY=$OPTARG
	    ;;

	d)
	    DISKSIZE=$OPTARG
	    ;;

	c)
	    ISO=$OPTARG
	    ;;
    esac
done

shift $(expr $OPTIND - 1 )
JAILNAME=$1

if [ "" == "${JAILNAME}" ]; then
    echo Missing jail name argument.
    exit 2
fi

if [ -e ${ZPATH}/${JAILNAME}/vm/disk.img ]; then
    echo ${JAILNAME} already exists. Skipping.
    exit 0
fi

# ensure creation of jail zfs volume
ensure_zfs "${ZPOOL}/${ZSTOREVOL}/${JAILNAME}"
# use caching in guest instead of host
ensure_zfs_metadata ${ZPOOL}/${ZSTOREVOL}/${JAILNAME}

# extract base into new volume
echo % tar -C ${ZPATH}/${JAILNAME} -xf ${ZPATH}/base.txz
if [ ! -e ${ZPATH}/${JAILNAME}/bin ]; then
    tar -C ${ZPATH}/${JAILNAME} -xf ${ZPATH}/base.txz
fi

# install kernel as well
echo % tar -C ${ZPATH}/${JAILNAME} -xf ${ZPATH}/kernel.txz
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

# create a jail.conf.d file for this jail
cat > /etc/jail.conf.d/${JAILNAME}.conf <<EOF
${JAILNAME} {
	    host.hostname = \${name};
	    vnet;
	    children.max = 0;

	    \$mac = "${MAC}";
	    \$imac = "${IMAC}";

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

echo % cat /etc/jail.conf.d/${JAILNAME}.conf
cat /etc/jail.conf.d/${JAILNAME}.conf

# set rc.conf settings for sub jail
ETC=${ZPATH}/${JAILNAME}/etc/rc.conf
echo % sysrc -f ${ETC} sendmail_enable=NONE
sysrc -f ${ETC} sendmail_enable=NONE
echo % sysrc -f ${ETC} ifconfig_bhyve0="DHCP"
sysrc -f ${ETC} ifconfig_bhyve0="DHCP"
echo % sysrc -f ${ETC} syslogd_flags="-ss"
sysrc -f ${ETC} syslogd_flags="-ss"
echo % sysrc -f ${ETC} cloned_interfaces="bridge0"
sysrc -f ${ETC} cloned_interfaces="bridge0"
echo % sysrc -f ${ETC} ifconfig_bridge0="addm bhyve0 up"
sysrc -f ${ETC} ifconfig_bridge0="addm bhyve0 up"

echo % cat ${ETC}
cat ${ETC}

# create iso directory for nullfs mount
echo % mkdir -p ${ZPATH}/${JAILNAME}/iso
mkdir -p ${ZPATH}/${JAILNAME}/iso

# create vm directory
echo % mkdir -p ${ZPATH}/${JAILNAME}/vm
mkdir -p ${ZPATH}/${JAILNAME}/vm
# create vm disk image
echo % truncate -s ${DISKSIZE} ${ZPATH}/${JAILNAME}/vm/disk.img
truncate -s ${DISKSIZE} ${ZPATH}/${JAILNAME}/vm/disk.img

# create fstab file
cat > ${ZPATH}/${JAILNAME}.fstab <<EOF
${ZPATH}/iso    ${ZPATH}/${JAILNAME}/iso nullfs ro 0 0
EOF
echo % cat ${ZPATH}/${JAILNAME}.fstab
cat ${ZPATH}/${JAILNAME}.fstab

# start the jail
echo % service jail onestart ${JAILNAME}
service jail onestart ${JAILNAME}

# remove any previously set proxy settings
unset http_proxy
unset https_proxy

# install bhyve firmware
echo % jexec ${JAILNAME} pkg install -y edk2-bhyve tmux
jexec ${JAILNAME} pkg install -y edk2-bhyve tmux

# for installation, we set up a tap interface
# and connect it to the vm bridge
echo % jexec ${JAILNAME} ifconfig tap create
TAP=$(jexec ${JAILNAME} ifconfig tap create)
echo ${TAP}
echo % jexec ${JAILNAME} ifconfig ${TAP} ether ${VMMAC}
jexec ${JAILNAME} ifconfig ${TAP} ether ${VMMAC}
echo % jexec ${JAILNAME} ifconfig bridge0 addm ${TAP}
jexec ${JAILNAME} ifconfig bridge0 addm ${TAP}

echo % jexec ${JAILNAME} bhyvectl --create --vm=${JAILNAME}
jexec ${JAILNAME} bhyvectl --create --vm=${JAILNAME}

if [ "0" != "$?" ]; then
    echo Bhyve failed.
    exit 1
fi

echo % jexec ${JAILNAME} tmux new-session -d -s bhyve "bhyve \
      -H -c 2 -D -l com1,stdio \
      -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
      -m ${MEMORY} \
      -s 0,hostbridge \
      -s 1,ahci-cd,/iso/${ISO} \
      -s 2,nvme,/vm/disk.img \
      -s 3,lpc \
      -s 4,virtio-net,${TAP} \
      ${JAILNAME}"

# then start installation
jexec ${JAILNAME} tmux new-session -d -s bhyve "bhyve \
      -H -c 2 -D -l com1,stdio \
      -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
      -m ${MEMORY} \
      -s 0,hostbridge \
      -s 1,ahci-cd,/iso/${ISO} \
      -s 2,nvme,/vm/disk.img \
      -s 3,lpc \
      -s 4,virtio-net,${TAP} \
      ${JAILNAME}"

echo % jexec ${JAILNAME} tmux attach-session -t bhyve
jexec ${JAILNAME} tmux attach-session -t bhyve

echo % jexec ${JAILNAME} bhyvectl --destroy --vm=${JAILNAME}
jexec ${JAILNAME} bhyvectl --destroy --vm=${JAILNAME}

# create bhyve start up script
mkdir -p ${ZPATH}/${JAILNAME}/usr/local/bin
cat > ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart <<EOF
#!/bin/sh

RESULT=0

TAP=\$(ifconfig tap create)
ifconfig \${TAP} ether ${VMMAC}

ifconfig bridge0 addm \${TAP}

while [ "0" == "\${RESULT}" ]; do
      bhyvectl --create --vm=${JAILNAME}
      /usr/bin/cpuset -l 1-8 \\
            /usr/sbin/bhyve \\
      		      -H -c 2 -D -l com1,stdio \\
		      -l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \\
		      -m ${MEMORY} \\
		      -s 0,hostbridge \\
 		      -s 2,nvme,/vm/disk.img \\
 		      -s 3,lpc \\
 		      -s 4,virtio-net,\${TAP} \\
 		      ${JAILNAME}

      RESULT=\$?
      bhyvectl --destroy --vm=${JAILNAME}
done

ifconfig \${TAP} destroy

EOF
chmod 755 ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart
echo % cat ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart
cat ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart
echo % chmod 755 ${ZPATH}/${JAILNAME}/usr/local/bin/bhyvestart

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
echo % cat ${ZPATH}/${JAILNAME}/usr/local/etc/rc.d/bhyve
cat ${ZPATH}/${JAILNAME}/usr/local/etc/rc.d/bhyve
echo % chmod 755 ${ZPATH}/${JAILNAME}/usr/local/etc/rc.d/bhyve

# enable bhyve rc.d script
echo % jexec ${JAILNAME} sysrc -f ${ETC} bhyve_enable=YES
jexec ${JAILNAME} sysrc -f ${ETC} bhyve_enable=YES

# stop jail
echo % service jail onestop ${JAILNAME}
service jail onestop ${JAILNAME}

# restart with rc.local startup
echo % service jail onestart ${JAILNAME}
service jail onestart ${JAILNAME}

# add jail to activation list
echo % sysrc jail_list+="${JAILNAME}"
sysrc jail_list+="${JAILNAME}"

# use the following command in host to check resource usage
# rctl -h -u jail:lab.<jailname>
