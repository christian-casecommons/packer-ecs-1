#!/bin/sh

# Stop docker auto-starting on instance launch (will be re-enabled by firstrun
# script), then clean up residual logs from image

set -e

echo "### Performing final clean-up tasks ###"
sudo service docker stop
sudo chkconfig docker off
sudo rm -f /var/log/docker /var/log/ecs/*
# An intermittent failure scenario sees this created as a directory when the
# ECS agent attempts to map it into its container, so do rm -Rf just in case
sudo rm -Rf /var/run/docker.sock
# https://github.com/docker/docker/issues/17691
sudo rm -Rf /var/lib/docker/containers/* /var/lib/docker/linkgraph.db
