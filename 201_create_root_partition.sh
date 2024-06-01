#!/bin/sh

# Creates a disk image with an UEFI and root partition
# with an fstab set to mount an rw-partition

DISKNAME="${1:-disk}"
DISKSIZE="${2:-20g}"

if [ -e config.sh ]; then
    . ./config.sh
fi

ZPATH=${ZPATH:=/lab2}

if [ "" != "$3" ]; then
    ZPATH=$3
fi

echo DISKNAME=${DISKNAME}
echo DISKSIZE=${DISKSIZE}
echo ZPATH=${ZPATH}

echo Press ENTER to continue.
read ENTER

rm -f ${DISKNAME}_root.img
rm -f ${DISKNAME}_rw.img
rm -f ${DISKNAME}_uefi.img

# create image file
truncate -s 100m ${DISKNAME}_uefi.img
truncate -s 10g ${DISKNAME}_root.img
truncate -s ${DISKSIZE} ${DISKNAME}_rw.img

# map disk image to device node
MD=$(mdconfig -t vnode -f ${DISKNAME}_root.img)
MDRW=$(mdconfig -t vnode -f ${DISKNAME}_rw.img)
MDUEFI=$(mdconfig -t vnode -f ${DISKNAME}_uefi.img)

# create partition table for root disk
gpart create -s gpt ${MD}
gpart add -t efi -s 100M ${MD}
gpart add -t freebsd ${MD}
gpart modify -i 1 -l boot ${MD}
gpart modify -i 2 -l root ${MD}

# create partition table for rw disk
gpart create -s gpt ${MDRW}
gpart add -t freebsd-swap -s 2G -l swap ${MDRW}
gpart add -t freebsd -s 1G -l home ${MDRW}
gpart add -t freebsd -s 2G -l tmp ${MDRW}
gpart add -t freebsd -s 8G -l var ${MDRW}
gpart add -t freebsd -l usr_local ${MDRW}

# Set up UEFI disk
gpart create -s gpt ${MDUEFI}
gpart add -t efi -l efi ${MDUEFI}

echo Installing bootcode...
gpart bootcode -p /boot/gptboot -i 1 ${MD}
gpart bootcode -p /boot/gptboot -i 1 ${MDUEFI}

gpart show ${MDUEFI}
echo About to format /dev/${MDUEFI}p1
read GO

newfs_msdos /dev/${MDUEFI}p1
mount /dev/${MDUEFI}p1 /mnt

mkdir -p /mnt/efi/boot
cp /boot/loader.efi /mnt/efi/boot/bootx64.efi

umount /mnt

echo Completed partition table:
gpart show ${MD}

ls /dev/${MD}*

echo About to format /dev/${MD}s2...
read continue
newfs /dev/${MD}s2
newfs_msdos /dev/${MD}p1

echo Completed RW partition table:
gpart show ${MDRW}
ls /dev/${MDRW}*

echo About to format /dev/${MDRW}s2-5
read continue
newfs /dev/${MDRW}s2
newfs /dev/${MDRW}s3
newfs /dev/${MDRW}s4
newfs /dev/${MDRW}s5

ROOT=/mnt

mkdir -p ${ROOT}

mount /dev/${MD}s2 ${ROOT}
mkdir -p ${ROOT}/tmp
mkdir -p ${ROOT}/usr/local
mkdir -p ${ROOT}/home
mkdir -p ${ROOT}/var

# Mount RW volumes
mount /dev/${MDRW}s2 ${ROOT}/home
mount /dev/${MDRW}s3 ${ROOT}/tmp
mount /dev/${MDRW}s4 ${ROOT}/var
mount /dev/${MDRW}s5 ${ROOT}/usr/local

# Extracting base...
tar -C ${ROOT} -xf ${ZPATH}/base.txz
# Extracting kernel and boot
tar -C ${ROOT} -xf ${ZPATH}/kernel.txz

# mount EFI partition
mkdir -p ${ROOT}/boot/efi
mount -t msdos /dev/${MD}p1 ${ROOT}/boot/efi

# install efi boot loader
mkdir -p ${ROOT}/boot/efi/efi/boot
cp ${ROOT}/boot/loader.efi ${ROOT}/boot/efi/efi/boot/bootx64.efi

# indicate root partition to loader
cat >> ${ROOT}/boot/loader.conf <<EOF
vfs.root.mountfrom="ufs:gpt/root"
EOF

# add fstab mount points
cat > ${ROOT}/etc/fstab <<EOF
# Root partition definition - completed by boot process
/dev/gpt/root	     /		ufs	rw	0	0

/dev/gpt/boot	     /boot/efi	msdos	rw	0	0

/dev/gpt/home	     /home	ufs	rw	0	0
/dev/gpt/tmp	     /tmp	ufs	rw	0	0
/dev/gpt/var	     /var	ufs	rw	0	0
/dev/gpt/usr_local   /usr/local	ufs	rw	0	0

/dev/gpt/swap	     none	swap	sw	0	0
EOF

# Fix rc.conf
mkdir -p ${ROOT}/var/etc
ln -s /var/etc/rc.conf ${ROOT}/etc/rc.conf
# Fix resolv.conf
rm -f ${ROOT}/etc/resolv.conf
ln -s /var/etc/resolv.conf ${ROOT}/etc/resolv.conf
# Fix user and group db and passwords
# Don't do this if you want to prevent anyone from
# being able to add users or groups
mv ${ROOT}/etc/master.passwd ${ROOT}/var/etc/
mv ${ROOT}/etc/passwd ${ROOT}/var/etc
mv ${ROOT}/etc/group ${ROOT}/var/etc
ln -s /var/etc/master.passwd ${ROOT}/etc/master.passwd
ln -s /var/etc/passwd ${ROOT}/etc/passwd
ln -s /var/etc/group ${ROOT}/etc/group

RC=${ROOT}/var/etc/rc.conf

echo sendmail_enable=NONE >> ${RC}
echo securelevel=3 >> ${RC}
echo clear_tmp_enable="YES" >> ${RC}
echo 'syslogd_flags="-ss"' >> ${RC}
echo 'hostname="baseimage"' >> ${RC}

# set some basic security sysctls
cat >> ${ROOT}/etc/sysctl.conf <<EOF
security.bsd.see_other_uids=0
security.bsd.see_other_gids=0
security.bsd.see_jail_proc=0
security.bsd.unprivileged_read_msgbuf=0
security.bsd.unprivileged_proc_debug=0
kern.randompid=1
EOF

# need a helper script to fix late rc.conf loading
cat >> ${ROOT}/etc/rc.local <<EOF
#!/bin/sh
service hostname restart
service securelevel onestart
service syslogd restart
service sysctl restart
service cleartmp start > /dev/null 2>&1
service sendmail stop > /dev/null 2>&1
service sendmail start > /dev/null 2>&1
EOF

umount ${ROOT}/usr/local
umount ${ROOT}/home
umount ${ROOT}/var
umount ${ROOT}/tmp
umount ${ROOT}/boot/efi
umount ${ROOT}

# release memory mapping
mdconfig -d -u ${MD}
mdconfig -d -u ${MDRW}
mdconfig -d -u ${MDUEFI}
