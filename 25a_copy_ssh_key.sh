#!/bin/sh

set -x

ssh-copy-id -i .ssh/id_ecdsa chris@10.193.167.3
scp -i .ssh/id_ecdsa nfs/02_setup_nfs_client.sh chris@10.193.167.3:


