#!/bin/sh
set -e

# Set the Docker bridge interface to CGNAT (RFC 6598) address space
subnet=100.64.0.1/24

# Override default startup timeout since we've observed longer start times
timeout=60

echo "### Setting Docker bridge interface subnet to $subnet ###"
sudo sed -i -e "s|^\(OPTIONS=\".*\)\"$|\1 --bip $subnet\"|" /etc/sysconfig/docker
echo "### Setting docker startup timeout to $timeout seconds ###"
sudo sed -i -e "s/up to 10/up to $timeout/" -e "s/tries -lt 10/tries -lt $timeout/" /etc/init.d/docker