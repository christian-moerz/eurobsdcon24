#!/bin/sh

set -x

zfs snapshot zroot/labjails/freebsd-vm@test

# Use zfs list to list available snapshots
zfs list -t snapshot

# create a new vm - in a jail, we need to do this manually
bhyvectl --create --vm=freebsd-vm

# We create a tap with prefix tap10001 because that is
# passed through to our machine via devfs
ifconfig tap10001 create

# Start up a bhyve virtual machine with a local network interface
# ahci-cd is now removed, because we want to boot the installed system
bhyve \
	-k freebsd-vm.conf \
	freebsd-vm &

PID=$!

# tap10001 was created now
ifconfig tap10001 name vm0
ifconfig vmswitch addm vm0

wait ${PID}

# Destroy the previously created vm
# In a jail we MUST do this before shutting it down
# otherwise, the jail id/name is inherited by the host
# and when the jail gets restarted, this vm won't be able
# to start because it's already "known" by the host
bhyvectl --destroy --vm=freebsd-vm

ifconfig vm0 destroy

# Now roll back everything
zfs rollback zroot/labjails/freebsd-vm@test

# We remove the snapshot after not needing it anymore
zfs destroy zroot/labjails/freebsd-vm@test

# Then start like 09
./09_start_with_config.sh

