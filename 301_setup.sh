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
cat >> /etc/sysctl.conf <<DOT
security.bsd.see_other_uids=0
security.bsd.see_other_gids=0
security.bsd.see_jail_proc=0
security.bsd.unprivileged_read_msgbuf=0
security.bsd.unprivileged_proc_debug=0
kern.randompid=1
DOT

pw useradd lab -m -G wheel -s /bin/csh
echo labpass | pw usermod lab -n lab -h 0
mkdir -p /home/lab/.ssh
echo ${PUBKEY} > /home/lab/.ssh/authorized_keys
chown -R lab:lab /home/lab/.ssh
chmod 700 /home/lab/.ssh
chmod 600 /home/lab/.ssh/authorized_keys

EOF
}

gen_media()
{
    mkdir -p ${ZPATH}/iso/setup
    tar -C ${ZPATH}/iso/setup -xf ${ZPATH}/iso/freebsd.iso
    write_installerconfig
    # finally, package up as iso again
    sh /usr/src/release/amd64/mkisoimages.sh -b '13_0_RELEASE_AMD64_CD' ${ZPATH}/iso/$1.iso ${ZPATH}/iso/setup
    
    # clean up again
    rm -fr ${ZPATH}/iso/setup
}

# setup base jail after first start
./102_setup_subjail.sh

# setup switch
./103_setup_switch.sh

# we prepare installation media for the three servers
if [ ! -e /usr/src/UPDATING ]; then
    echo Missing /usr/src
    exit 2
fi


CONF_HOSTNAME="unbound"
CONF_IP="10.193.167.10"
CONF_SUBNET="255.255.255.0"
CONF_ROUTER=${SWITCHIP}

gen_media unbound

CONF_HOSTNAME="mail1"
CONF_IP="10.193.167.11"
gen_media mail1

CONF_HOSTNAME="mail2"
CONF_IP="10.193.167.12"
gen_media mail2

./104_setup_vmjail.sh -m 1G -c unbound.iso

