#!/bin/sh

set -x

if [ -e config.sh ]; then
        . ./config.sh
fi

zfs snapshot ${ZPOOL}/${ZSTOREVOL}/freebsd-vm@test

# Use zfs list to list available snapshots
zfs list -t snapshot

./10_start_with_config.sh

# Now roll back everything
zfs rollback ${ZPOOL}/${ZSTOREVOL}/freebsd-vm@test

# We remove the snapshot after not needing it anymore
zfs destroy ${ZPOOL}/${ZSTOREVOL}/freebsd-vm@test

# Then start like 09
./10_start_with_config.sh

