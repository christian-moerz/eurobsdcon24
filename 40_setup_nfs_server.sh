#!/bin/sh

# set -x
set -e

if [ -e config.sh ]; then
	. ./config.sh
fi
ZPATH=${ZPATH:=/lab}
ZPOOL=${ZPOOL:=zroot}
ZSTOREVOL=${ZSTOREVOL:=labjails}
SWITCHNAME=${SWITCHNAME:=vmswitch}

ifconfig ${SWITCHNAME} > /dev/null 2>&1

if [ "0" != "$?" ]; then
    # run switch setup
    ./06_setup_vmbridge.sh
fi

# prepare an iso file for quick setup
if [ ! -e ${ZPATH}/iso/nfs-server.iso ]; then
    echo % mkdir -p ${ZPATH}/iso/setup
    mkdir -p ${ZPATH}/iso/setup
    echo % tar -C ${ZPATH}/iso/setup -xf ${ZPATH}/iso/freebsd.iso
    tar -C ${ZPATH}/iso/setup -xf ${ZPATH}/iso/freebsd.iso
    
    cat >> ${ZPATH}/iso/setup/etc/installerconfig <<-EOF
PARTITIONS=DEFAULT				  
DISTRIBUTIONS="kernel.txz base.txz"
export nonInteractive="YES"
    
#!/bin/sh
sysrc ifconfig_DEFAULT=DHCP
sysrc sshd_enable=YES
sysrc hostname=freebsd-nfs
sysrc ifconfig_vtnet0="inet 10.193.167.2 netmask 255.255.255.0"
sysrc defaultrouter="10.192.167.1"
pw useradd chris -m -G wheel -s /bin/csh
cat >> /etc/sysctl.conf <<-DOT
security.bsd.see_other_uids=0
security.bsd.see_other_gids=0
security.bsd.see_jail_proc=0
security.bsd.unprivileged_read_msgbuf=0
security.bsd.unprivileged_proc_debug=0
kern.randompid=1
DOT
EOF
    echo % cat ${ZPATH}/iso/setup/etc/installerconfig
    cat ${ZPATH}/iso/setup/etc/installerconfig

    echo % sh /usr/src/release/amd64/mkisoimages.sh -b 13_0_RELEASE_AMD64_CD ${ZPATH}/iso/nfs-server.iso ${ZPATH}/iso/setup
    sh /usr/src/release/amd64/mkisoimages.sh -b 13_0_RELEASE_AMD64_CD ${ZPATH}/iso/nfs-server.iso ${ZPATH}/iso/setup

    echo % rm -fr ${ZPATH}/iso/setup
    rm -fr ${ZPATH}/iso/setup
fi

# remove 10.193.167.2 from dhcp range
# because we use that as static ip for
# our nfs server

# make sure we are not running the nfs server ip in the dynamic range
sed -i '' 's@range 10.193.167.2 10.193.167.100;@range 10.193.167.3 10.193.167.100;@' /usr/local/etc/dhcpd.conf
service isc-dhcpd enable
service isc-dhcpd restart

./104_setup_vmjail.sh -c nfs-server.iso freebsd-nfs

#
# add diskless option to dhcp
#
mkdir -p /usr/local/etc/dhcpd
if [ ! -e /usr/local/etc/dhcpd.base ]; then
    cp /usr/local/etc/dhcpd.conf /usr/local/etc/dhcpd.base
fi
cat > /usr/local/etc/dhcpd/00_diskless <<EOF
group diskless {
    next-server 10.193.167.2;
    filename "pxeboot";
    option root-path "10.193.167.2:/nfs/vm01/";

    host client {
       hardware ethernet 00:00:00:ff:ff:03;
       fixed-address 10.193.167.3;
    }
}

EOF

cat /usr/local/etc/dhcpd.base /usr/local/etc/dhcpd/* > /usr/local/etc/dhcpd.conf

echo % cat /usr/local/etc/dhcpd.conf
cat /usr/local/etc/dhcpd.conf

echo % service isc-dhcpd restart
service isc-dhcpd restart


