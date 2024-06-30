#!/bin/sh

BASE=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
KERNEL=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
ISO=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso

# Utility functions
#

# ensure that a zfs volume exists
ensure_zfs()
{
    zfs list | grep $1 > /dev/null 2>&1
    if [ "0" != "$?" ]; then
	echo % zfs create $1
	zfs create $1
    fi
}

ensure_zfs_mountpoint()
{
    MPOINT=$(zfs get -H mountpoint $2 | awk '{print $3}')
    if [ "${MPOINT}" != "$1" ]; then
	echo % zfs set mountpoint=$1 $2
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
