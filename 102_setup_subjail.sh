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
ROUTENET=10.191.169

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
TEMPLATE_ROUTED=/etc/jail.conf.d/jail_routed.template
cp subjail_routed.template ${TEMPLATE_ROUTED}

# replace variables in template
sed -i '' "s@ZPATH@${ZPATH}@g" ${TEMPLATE}
sed -i '' "s@ZPATH@${ZPATH}@g" ${TEMPLATE_ROUTED}

# make sure we are not overwriting ROUTED twice
if [ -e config.sh ]; then
    sed -i '' '/ROUTED=/d' config.sh
fi

# write configuration into config file
cat >> config.sh <<EOF
ZPOOL=${ZPOOL}
ZSTOREVOL=${ZSTOREVOL}
ZPATH=${ZPATH}
ROUTED=1
ROUTENET=${ROUTENET}
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
pkg install -y -f pkg git

# make sure we only keep variables once
# instead of repeating them
clean_config

# enable jail startup
sysrc jail_enable=YES

cd /usr/src
git clone -b releng/14.0 --depth 1 https://github.com/freebsd/freebsd-src /usr/src

# Prepare a quick setup media
mkdir -p ${ZPATH}/iso/setup
tar -C ${ZPATH}/iso/setup -xvf ${ZPATH}/iso/freebsd.iso

# write an installer config
cat >> ${ZPATH}/iso/setup/etc/installerconfig <<EOF
PARTITIONS=DEFAULT
DISTRIBUTIONS="kernel.txz base.txz"
export nonInteractive="YES"

#!/bin/sh
sysrc ifconfig_DEFAULT=DHCP
sysrc sshd_enable=YES
sysrc hostname=quick-setup
cat >> /etc/sysctl.conf <<DOT
security.bsd.see_other_uids=0
security.bsd.see_other_gids=0
security.bsd.see_jail_proc=0
security.bsd.unprivileged_read_msgbuf=0
security.bsd.unprivileged_proc_debug=0
kern.randompid=1
DOT
EOF

# finally, package up as iso again
sh /usr/src/release/amd64/mkisoimages.sh -b '13_0_RELEASE_AMD64_CD' ${ZPATH}/iso/quick.iso ${ZPATH}/iso/setup

# clean up again
rm -fr ${ZPATH}/iso/setup

# setup a script that connects to a bhyve jail later
cat >> /usr/local/bin/connect <<EOF
#!/bin/sh
if [ "" == "\$1" ]; then
   echo Missing jail name.
   exit 2
fi

jexec \$1 tmux attach-session -t bhyve
EOF
chmod 755 /usr/local/bin/connect
