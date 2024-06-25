#!/bin/sh

# set up a routed vm jail instead of a bridged on
# for this, we get the routed environment from config.sh
# and create a new /29 network for our sub jail

set -x

if [ ! -e config.sh ]; then
    echo Missing main jail configuration file.
    exit 1
fi

. ./config.sh
. ./utils.sh

JAILNAME=$1

if [ "" == "${JAILNAME}" ]; then
    echo Missing jail name argument.
    exit 2
fi
