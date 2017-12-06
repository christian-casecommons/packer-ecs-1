import os
import json
import pytest

def test_ecs_agent_is_running(host):
  cmd = host.run("status ecs")
  assert cmd.rc == 0
  assert 'running' in cmd.stdout

def test_ecs_agent_metadata_is_running(host):
  cmd = host.run("curl -fs --connect-timeout 5 localhost:51678/v1/metadata")
  assert cmd.rc == 0

@pytest.mark.skipif(os.environ.get("ECS_CLUSTER") is None,
                    reason="ECS_CLUSTER is not defined")
def test_ecs_agent_is_registered_to_cluster(host):
  cmd = host.run("curl -fs --connect-timeout 5 localhost:51678/v1/metadata")
  metadata = json.loads(cmd.stdout)
  assert metadata['Cluster'] == os.environ['ECS_CLUSTER']
  