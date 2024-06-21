#!/bin/sh

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
