#!/usr/bin/env bash
set -e

# Render configuration files
confd -onetime -backend env

# Set localtime
ln -sf /usr/share/zoneinfo/${TIME_ZONE:-America/Los_Angeles} /etc/localtime

# Enable and start services
/sbin/chkconfig ntpd on
/sbin/chkconfig awslogs on
/sbin/chkconfig docker on
/sbin/service ntpd start
/sbin/service awslogs start
/sbin/service docker start
start ecs

# Exit gracefully if ECS_CLUSTER is not defined
if [[ -z ${ECS_CLUSTER} ]]
  then
  echo "Skipping ECS agent check as ECS_CLUSTER variable is not defined"
  exit 0
fi

# Loop until ECS agent has registered to ECS cluster
echo "Checking ECS agent is joined to ${ECS_CLUSTER}"
until [[ "$(curl --fail --silent http://localhost:51678/v1/metadata | jq '.Cluster // empty' -r -e)" == ${ECS_CLUSTER} ]]
  do printf '.'
  sleep 5
done
echo "ECS agent successfully joined to ${ECS_CLUSTER}"

# Pause if PAUSE_TIME is defined
if [[ -n ${PAUSE_TIME} ]]
  then
  echo "Pausing for ${PAUSE_TIME} seconds..."
  sleep ${PAUSE_TIME}
fi