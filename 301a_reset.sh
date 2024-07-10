#!/bin/sh

# Reset mail1 server
service jail stop mail1
service jail stop unbound

zfs rollback zroot/labdisk/mail1@installed
zfs rollback zroot/labdisk/unbound@installed

service jail start unbound
service jail start mail1

#cp ~lclchristianm/Documents/workspace/mailsrv/install.sh mailsrv/install.sh
echo Make sure to replace install.sh first!
cat mailsrv/install.sh | grep pkg > /dev/null
if [ "0" == "$?" ]; then
    sed -i '' '13,31d' mailsrv/install.sh
fi
