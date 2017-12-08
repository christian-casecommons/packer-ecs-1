import os
import json
import pytest
from .conftest import HOSTS
testinfra_hosts = HOSTS

def test_ecs_agent_is_running(host):
  cmd = host.run("status ecs")
  assert cmd.rc == 0
  assert 'running' in cmd.stdout

def test_ecs_agent_metadata_is_running(host):
  cmd = host.run("curl -fs --connect-timeout 5 localhost:51678/v1/metadata")
  assert cmd.rc == 0

def test_ecs_agent_is_registered_to_cluster(host, ecs_cluster):
  cmd = host.run("curl -fs --connect-timeout 5 localhost:51678/v1/metadata")
  metadata = json.loads(cmd.stdout)
  assert metadata['Cluster'] == ecs_cluster

def test_ecs_agent_is_active(ecs_client, ecs_cluster, ec2_instances):
  ci_list = ecs_client.list_container_instances(cluster=ecs_cluster)
  container_instances = ecs_client.describe_container_instances(
    cluster=ecs_cluster,
    containerInstances=ci_list['containerInstanceArns']
  )
  status = [ci['status'] == 'ACTIVE' for ci in container_instances['containerInstances'] if ci['ec2InstanceId'] in ec2_instances]
  assert all(status)