from .conftest import HOSTS
testinfra_hosts = HOSTS

def test_docker_is_enabled_and_running(host):
  docker = host.service("docker")
  assert docker.is_running
  assert docker.is_enabled

def test_docker_bridge_is_removed(host):
  cmd = host.run('docker network ls --filter driver=bridge -q')
  assert not cmd.stdout