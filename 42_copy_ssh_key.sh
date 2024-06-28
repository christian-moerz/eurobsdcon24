#!/bin/sh

set -x

ssh-copy-id -i .ssh/id_ecdsa chris@10.193.167.2
scp -i .ssh/id_ecdsa nfs/01_setup_nfs_server.sh chris@10.193.167.2:
# copy txz files as well
scp -i .ssh/id_ecdsa *.txz chris@10.193.167.2:

