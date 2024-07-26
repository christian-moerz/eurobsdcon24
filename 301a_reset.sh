#!/bin/sh

reset_jail()
{
    service jail stop $1
    zfs rollback zroot/labdisk/$1@installed
    service jail start $1
}

reset_jail unbound
reset_jail mail1
reset_jail mail2
reset_jail client

#cp ~lclchristianm/Documents/workspace/mailsrv/install.sh mailsrv/install.sh
echo Make sure to replace install.sh first!
cat mailsrv/install.sh | grep pkg > /dev/null
if [ "0" == "$?" ]; then
    sed -i '' '13,31d' mailsrv/install.sh
fi
