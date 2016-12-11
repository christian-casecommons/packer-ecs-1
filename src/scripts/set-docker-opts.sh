#!/bin/sh
set -e

# Set the Docker bridge interface to CGNAT (RFC 6598) address space
# Set user namespace remap setting
subnet=100.64.0.1/24
remap=default

echo "### Setting Docker bridge interface subnet to $subnet ###"
sudo sed -i -e "s|^\(OPTIONS=\".*\)\"$|\1 --bip $subnet\"|" /etc/sysconfig/docker
