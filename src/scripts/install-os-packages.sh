#!/bin/sh
set -e

# Add additional OS packages
packages="aws-cfn-bootstrap awslogs jq"

# Exclude Docker and ECS Agent from update
sudo yum -y -x docker\* -x ecs\* update
echo "### Installing extra packages: $packages ###"
sudo yum -y install $packages
