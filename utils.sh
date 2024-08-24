#!/bin/sh

BASE=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
KERNEL=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
ISO=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso

# Utility functions
#

# ensure that a zfs volume exists
ensure_zfs()
{
    echo % zfs create $1
    zfs list | grep $1 > /dev/null 2>&1
    if [ "0" != "$?" ]; then
	zfs create $1
    fi
}

ensure_zfs_metadata() {
    echo % zfs set primarycache=metadata $1
    zfs set primarycache=metadata $1
}

ensure_zfs_mountpoint()
{
    MPOINT=$(zfs get -H mountpoint $2 | awk '{print $3}')
    echo % zfs set mountpoint=$1 $2
    if [ "${MPOINT}" != "$1" ]; then
	zfs set mountpoint=$1 $2
    fi
}

ensure_zfs_jailed()
{
    JAILED=$(zfs get -H jailed $1 | awk '{print $3}')
    if [ "${JAILED}" != "on" ]; then
	echo % zfs set jailed=on $1
	zfs set jailed=on $1
    fi
}

ensure_cp()
{
    echo % cp $1 $2
    cp $1 $2
}

# ensure zfs mount point is set to particular
# path
ensure_zfs_mountpoint()
{
    MOUNTPATH=$(zfs get -H mountpoint $2 | awk '{ print $3 }')
    if [ "${MOUNTPATH}" != "$2" ]; then
	mkdir -p $1
	zfs set mountpoint=$1 $2
    fi
}

# contract config.sh
clean_config()
{
    cat config.sh | sort | uniq > config.sh2
    mv config.sh2 config.sh
}

# make sure we are running inside jail
ensure_jailed()
{
    if [ `sysctl -n security.jail.jailed` != "1" ]; then
	echo Not running inside jail!
	exit 1
    fi
}

ensure_unjailed()
{
    if [ `sysctl -n security.jail.jailed` != "0" ]; then
        echo Not running outside jail!
        exit 1
    fi
}

# ensure a download is completed
ensure_download()
{
    OUTPUT=$1
    URL=$2
    BNAME=$(basename $1)

    if [ ! -e ${OUTPUT} ]; then
	if [ -e ${BNAME} ]; then
	    # if we have the file locally, we use that
	    # instead of downloading it frmo the internet

	    echo % cp ${BNAME} ${OUTPUT}
	    cp ${BNAME} ${OUTPUT}
	else
	    echo % fetch -o ${OUTPUT} ${URL}
	    fetch -o ${OUTPUT} ${URL}
	fi
    fi
}

# ensure existence of a lab download
ensure_lab_download()
{
    ensure_download ${LABPATH}/$1 $2
}

# ensure a core download
ensure_core_download()
{
    ensure_download ${ZPATH}/$1 $2
}

ensure_newjail()
{
    if [ -e /etc/jail.conf.d/$1.conf ]; then
	echo Jail $1 already exists.
	exit 1
    fi
}

sysrc_file()
{
    echo % sysrc -f $1 $2
    sysrc -f $1 $2
}

generate_ssh()
{
    if [ ! -e .ssh/id_ecdsa ]; then
	mkdir .ssh
	ssh-keygen -f .ssh/id_ecdsa -t ecdsa
    fi
}

await_ip() {
    CHECKED=1

    while [ "${CHECKED}" != "0" ]; do
	ping -c 1 $1 > /dev/null 2>&1
	CHECKED=$?
    done
    
    return 0
}

sleep_dot()
{
    echo -n Waiting
    COUNTER=$1
    while [ "$COUNTER" != "0" ]; do
	COUNTER=$((COUNTER-1))
	sleep 1
	echo -n .
    done
    echo ""
}

write_installerconfig()
{
    if [ "${NAMESERVER}" == "" ]; then
	echo "NAMESERVER not set"
	exit 2
    fi
    cat >> ${ZPATH}/iso/setup/etc/installerconfig <<EOF
PARTITIONS=DEFAULT				  
DISTRIBUTIONS="kernel.txz base.txz"		  
export nonInteractive="YES"			  

#!/bin/sh
sysrc ifconfig_DEFAULT="inet ${CONF_IP} netmask ${CONF_SUBNET}"
sysrc sshd_enable=YES
sysrc hostname=${CONF_HOSTNAME}
sysrc defaultrouter=${CONF_ROUTER}

echo nameserver ${NAMESERVER} > /etc/resolv.conf

pw useradd lab -m -G wheel -s /bin/csh
echo labpass | pw usermod lab -n lab -h 0
mkdir -p /home/lab/.ssh
echo ${PUBKEY} > /home/lab/.ssh/authorized_keys
chown -R lab:lab /home/lab/.ssh
chmod 700 /home/lab/.ssh
chmod 600 /home/lab/.ssh/authorized_keys

echo "security.bsd.see_other_uids=0" >> /etc/sysctl.conf
echo "security.bsd.see_other_gids=0" >> /etc/sysctl.conf
echo "security.bsd.see_jail_proc=0" >> /etc/sysctl.conf
echo "security.bsd.unprivileged_read_msgbuf=0" >> /etc/sysctl.conf
echo "security.bsd.unprivileged_proc_debug=0" >> /etc/sysctl.conf
echo "kern.randompid=1" >> /etc/sysctl.conf

mkdir -p /usr/local/etc
cat <<BOT >/usr/local/etc/doas.conf
permit nopass lab
BOT

EOF
}

gen_media()
{
    if [ ! -e ${ZPATH}/iso/$1.iso ]; then
	mkdir -p ${ZPATH}/iso/setup
	tar -C ${ZPATH}/iso/setup -xf ${ZPATH}/iso/freebsd.iso
	write_installerconfig

	# finally, package up as iso again
	sh /usr/src/release/amd64/mkisoimages.sh -b '13_0_RELEASE_AMD64_CD' ${ZPATH}/iso/$1.iso ${ZPATH}/iso/setup
	
	# clean up again
	rm -fr ${ZPATH}/iso/setup
    fi
}

ssh_copy()
{
    scp -o ConnectionAttempts=50 -o ConnectTimeout=3600 \
	-i .ssh/id_ecdsa $1 lab@10.193.167.$2:
}

build_ip()
{
    BASEIP=$1
    NEWID=$2
    NETID=$(echo ${BASEIP} | awk -F. '{print $1 "." $2 "." $3 "." }')
    echo ${NETID}${NEWID}
}

reset_jail()
{
    service jail stop $1
    zfs rollback zroot/labdisk/$1@installed
    service jail start $1
}
