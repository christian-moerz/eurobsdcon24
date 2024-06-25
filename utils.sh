#!/bin/sh

BASE=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/base.txz
KERNEL=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/14.0-RELEASE/kernel.txz
ISO=http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso

# Utility functions
#

# ensure that a zfs volume exists
ensure_zfs()
{
    zfs list | grep $1
    if [ "0" != "$?" ]; then
	zfs create $1
    fi
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
	    cp ${BNAME} ${OUTPUT}
	else
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

