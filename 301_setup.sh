#!/bin/sh

#
# Sets up lab environment for mail server:
# 
# * creates a dns server VM
# * creates two mail server VMs to be able to
#   talk to one another
#
# We are using the bhyve 101 and bhyve 102 scripts
# to set this up
#
# We assume we are starting from an empty lab
# environment.
#
# 101_setup_jails.sh must have already been run
# This needs to run inside base jail
#

. ./utils.sh

ensure_jailed

if [ ! -e config.sh ]; then
    echo Missing config.sh.
    exit 1
fi

. ./config.sh

generate_ssh

PUBKEY=$(cat .ssh/id_ecdsa.pub)
NAMESERVER=${DNS}

write_installerconfig()
{
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

if [ "3" != "${STAGE}" ]; then

    # setup base jail after first start
    ./102_setup_subjail.sh

    # setup switch
    ./103_setup_switch.sh

    # we prepare installation media for the three servers
    if [ ! -e /usr/src/UPDATING ]; then
	echo Missing /usr/src
	exit 2
    fi

    echo "STAGE=3" >> config.sh
fi


CONF_HOSTNAME="unbound"
CONF_IP="10.193.167.10"
CONF_SUBNET="255.255.255.0"
CONF_ROUTER=${SWITCHIP}

gen_media unbound

CONF_HOSTNAME="mail1"
CONF_IP="10.193.167.11"
NAMESERVER="10.193.167.10"
SEARCH="ny-central.lab"
gen_media mail1

CONF_HOSTNAME="mail2"
CONF_IP="10.193.167.12"
SEARCH="eurobsdcon.lab"
gen_media mail2

#
# remove any previous entries from known hosts
#
sed -i '' '/10.193.167.10/d' /root/.ssh/known_hosts
sed -i '' '/10.193.167.11/d' /root/.ssh/known_hosts

./104_setup_vmjail.sh -m 1G -c unbound.iso unbound

./104_setup_vmjail.sh -m 4G -c mail1.iso mail1

./104_setup_vmjail.sh -m 4G -c mail2.iso mail2

gen_user()
{
    id $1 > /dev/null
    if [ "0" != "$?" ]; then
	pw user add $1 -m
	NEWPASS=$(echo $1.mail | openssl passwd -6 -stdin)
	chpass -p ${NEWPASS} $1
    fi
}

gen_user ny_central
gen_user eurobsdcon

# install a local mail client
pkg info | grep alpine > /dev/null
if [ "0" != "$?" ]; then
    pkg install -y alpine
fi

# after setting servers up, we install unbound and
# configure our two domains to talk to each other

if [ ! -e /ca ]; then

    # create a CA for our tests
    pkg install -y easy-rsa
    mkdir -p /ca
    CURRENT=$(pwd)
    cd /ca && easy-rsa init-pki
    easyrsa build-ca nopass
    
    # generate server certificates
    easyrsa build-server-full mail.ny-central.lab nopass
    easyrsa build-server-full mail.eurobsdcon.lab nopass
    
    cp /ca/pki/issued/mail.ny-central.lab.crt ${CURRENT}
    cp /ca/pki/private/mail.ny-central.lab.key ${CURRENT}
    cp /ca/pki/issued/mail.eurobsdcon.lab.crt ${CURRENT}
    cp /ca/pki/private/mail.eurobsdcon.lab.key ${CURRENT}

    pkg info | grep ca_root_nss > /dev/null
    if [ "0" != "$?" ]; then
	pkg install -y ca_root_nss
    fi

    # install the CA certificate locally, so we can trust
    # those mail servers when accessing as client
    install -m 0444 /ca/pki/ca.crt /usr/local/etc/ssl/ca.crt
    cat /ca/pki/ca.crt >> /usr/local/etc/ssl/cert.pem
    mkdir -p /usr/share/certs/trusted
    install -m 0444 /ca/pki/ca.crt /usr/share/certs/trusted/localca.pem
    certctl rehash

    cd ${CURRENT}
fi

# for simplicity, we create a single dhparam file for all
if [ ! -e dhparams.pem ]; then
    openssl dhparam -out dhparams.pem 4096
fi

# wait for unbound to complete booting
await_ip 10.193.167.10

ssh_copy()
{
    scp -i .ssh/id_ecdsa $1 lab@10.193.167.$2:
}

ssh_copy mailsrv/01_setup_unbound.sh 10
ssh_copy mailsrv/unbound.conf 10
ssh_copy 'mailsrv/*.zone' 10

echo Connecting to unbound - run 01_setup_unbound.sh!
echo Press ENTER to continue.
read ENTER
ssh -i .ssh/id_ecdsa lab@10.193.167.10

await_ip 10.193.167.11
sleep_dot 10

# connect to mail server 1 and set up mail domain
# ny-central.lab
ssh_copy mailsrv/install.sh 11
if [ -e clamav.tar.xz ]; then
    ssh_copy clamav.tar.xz 11
fi
if [ -e spamassassin.tar.xz ]; then
    ssh_copy spamassassin.tar.xz 11
fi
cp mailsrv/config.sh mailsrv/config.mail1.sh
sed -i '' 's/mailsrv.ny-central.local/mail1.ny-central.lab/' \
    mailsrv/config.mail1.sh
sed -i '' 's/ny-central.local/ny-central.lab/' \
    mailsrv/config.mail1.sh
sysrc -f mailsrv/config.mail1.sh NETWORKS="10.193.167.0/24"
sysrc -f mailsrv/config.mail1.sh SSHUSERS=lab
sysrc -f mailsrv/config.mail1.sh EXTIF=vtnet0
mv mailsrv/config.mail1.sh /tmp/config.sh
ssh_copy /tmp/config.sh 11
rm -f /tmp/config.sh

if [ -e mail.ny-central.lab.crt ]; then
    mv mail.ny-central.lab.crt /tmp/server.crt
    mv mail.ny-central.lab.key /tmp/server.key
    ssh_copy /tmp/server.crt 11
    ssh_copy /tmp/server.key 11
    rm -f /tmp/server.crt
    rm -f /tmp/server.key
fi
ssh_copy /ca/pki/ca.crt 11

ssh_copy dhparams.pem 11

echo Connecting to mail1 - run install.sh
echo Press ENTER to continue.
read ENTER
ssh -i .ssh/id_ecdsa lab@10.193.167.11

# Copy down dns record
scp -i .ssh/id_ecdsa lab@10.193.167.11:ny-central.lab.dns .
# Copy up to unbound
ssh_copy ny-central.lab.dns 10
# Copy follow up script to server
ssh_copy mailsrv/02_update_unbound.sh 10
ssh -i .ssh/id_ecdsa lab@10.193.167.10 'doas /bin/sh 02_update_unbound.sh'

echo Base setup completed.
