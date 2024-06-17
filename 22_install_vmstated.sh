#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

# Install vmstated
pkg install -y vmstated

# Set up vm switch
./06_setup_vmbridge.sh

mkdir -p /usr/local/etc/vmstated/freebsd

cat > /usr/local/etc/vmstated/freebsd/config <<EOF
freebsd {
        configfile = /usr/local/etc/vmstated/freebsd/bhyve_config;
        owner = root;
        bootrom = /usr/local/share/uefi-firmware/BHYVE_UEFI.fd;
        description = Test VM;

        generate_acpi_tables = true;
        vmexit_on_halt = true;
        autostart = true;

        hostbridge = default;

        consoles {
                console {
                        name = 'console0'
                        backend = '/dev/nmdm0A'
                }
        }
}
EOF

cat > /usr/local/etc/vmstated/freebsd/start_network <<EOF
#!/bin/sh
logger "Started start_network"
TAP=\$(/sbin/ifconfig tap create)
/sbin/ifconfig ${SWITCHNAME} addm \${TAP}
/sbin/ifconfig \${TAP} name freebsd0
echo Network started.
EOF
chmod 755 /usr/local/etc/vmstated/freebsd/start_network

cat > /usr/local/etc/vmstated/freebsd/stop_network <<EOF
#!/bin/sh
/sbin/ifconfig freebsd0 destroy
EOF
chmod 755 /usr/local/etc/vmstated/freebsd/stop_network

cp vmstated_config /usr/local/etc/vmstated/freebsd/bhyve_config

service vmstated enable
service vmstated start

vmstatedctl status

# set up disk
./02_setup_disk.sh

vmstatedctl start freebsd

