#!/bin/sh

#
# Set up web mail
#

MAIL_PLUGIN=https://github.com/nextcloud-releases/mail/releases/download/v3.7.6/mail-v3.7.6.tar.gz

set -x
set -e

. ./utils.sh

ensure_jailed

if [ ! -e config.sh ]; then
    echo Missing config.sh.
    exit 1
fi

. ./config.sh

CLOUD_IP=$(build_ip ${SWITCHIP} 13)
if [ "" == "${CLOUD_IP}" ]; then
    echo Missing SWITCHIP in config.sh
    exit 2
fi
DNS_IP=$(build_ip ${SWITCHIP} 10)

#
# prepare server certificate
#

if [ ! -e /ca ]; then
    echo Missing CA!
    exit 2
fi
if [ ! -e /ca/pki/issued/cloud.ny-central.lab.crt ]; then
    CURRENT=$(pwd)
    cd /ca
    easyrsa build-server-full cloud.ny-central.lab nopass -y
    cd ${CURRENT}
fi

if [ -e /root/.ssh/known_hosts ]; then
    sed -i '' "/${CLOUD_IP}/d" /root/.ssh/known_hosts
    sed -i '' '/cloud/d' /root/.ssh/known_hosts
fi

if [ ! -e /usr/src/UPDATING ]; then
    echo Missing /usr/src!
    exit 2
fi

PUBKEY=$(cat .ssh/id_ecdsa.pub)
CONF_HOSTNAME="cloud"
CONF_IP=$(build_ip ${SWITCHIP} 13)
CONF_SUBNET="255.255.255.0"
CONF_ROUTER="${SWITCHIP}"
NAMESERVER=$(build_ip ${SWITCHIP} 10)
SEARCH="ny-central.lab"
gen_media cloud

#
# prepare webserver
#
./104_setup_vmjail.sh -m 4G -c cloud.iso cloud

set +e
cat /etc/hosts | grep cloud > /dev/null
if [ "0" -ne "$?" ]; then
    echo "${CONF_IP} cloud" >> /etc/hosts
fi
set -e

#
# Create a DNS update script to add DNS IP
#
cat <<EOF >/tmp/update_dns.sh
#!/bin/sh
sed -i '' "/cloud/d" /usr/local/etc/unbound/ny-central.lab.zone
echo "cloud IN A ${CLOUD_IP}" >> /usr/local/etc/unbound/ny-central.lab.zone
service unbound reload
EOF
ssh_copy /tmp/update_dns.sh 10
ssh -i .ssh/id_ecdsa lab@${DNS_IP} 'doas /bin/sh update_dns.sh'

#
# prepare webmail config for ny-central.lab
#

cat <<EOF >/tmp/config.sh
DOMAIN=ny-central.lab
EOF

#
# Copy installation script and config to cloud host
#
ssh_copy /tmp/config.sh 13
rm /tmp/config.sh
ssh_copy websrv/install-nextcloud.sh 13

if [ -e nextcloud_mail.tar.gz ]; then
    ssh_copy nextcloud_mail.tar.gz 13
fi

if [ -e nextcloud.zip ]; then
    ssh_copy nextcloud.zip 13
fi

#
# Copy certificates
#
ssh_copy /ca/pki/ca.crt 13
cp /ca/pki/issued/cloud.ny-central.lab.crt /tmp/server.crt
cp /ca/pki/private/cloud.ny-central.lab.key /tmp/server.key

ssh_copy /tmp/server.crt 13
ssh_copy /tmp/server.key 13
rm /tmp/server.key /tmp/server.crt

echo Connecting to cloud - run install-nextcloud.sh
echo Press ENTER to continue.
read ENTER
ssh -i .ssh/id_ecdsa lab@${CLOUD_IP}

#
# Enable incoming firewall ruleset
#
sed -i '' "/${CLOUD_IP}/d" /etc/pf.conf
echo "pass inet proto tcp from any to ${CLOUD_IP} port { 80 443 }" >> /etc/pf.conf
pfctl -f /etc/pf.conf

