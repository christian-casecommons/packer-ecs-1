import anyconfig
import pytest
import os
from .conftest import HOSTS
testinfra_hosts = HOSTS

def test_awslogs_is_enabled_and_running(host):
  awslogs = host.service("awslogs")
  assert awslogs.is_running
  assert awslogs.is_enabled

@pytest.mark.skipif(os.environ.get("AWS_DEFAULT_REGION") is None,
                    reason="AWS_DEFAULT_REGION is not defined")
def test_awslogs_region_is_configured(host):
  awscli = host.file("/etc/awslogs/awscli.conf")
  config = anyconfig.loads(awscli.content, ac_parser="ini")
  assert config['default']['region'] == os.environ['AWS_DEFAULT_REGION']

def test_awslogs_config(host):
  awscli = host.file("/etc/awslogs/awslogs.conf")
  # anyconfig ini parser treats '%' as environment variable interpolator
  content = awscli.content.replace('%','%%')
  config = anyconfig.loads(content, ac_parser="ini")
  prefix = 'packer-test/ec2/ProxyAutoscalingGroup'
  assert config['/var/log/dmesg']['log_group_name'] == prefix + '/var/log/dmesg'
  assert config['/var/log/messages']['log_group_name'] == prefix + '/var/log/messages'
  assert config['/var/log/docker']['log_group_name'] == prefix + '/var/log/docker'
  assert config['/var/log/docker']['log_group_name'] == prefix + '/var/log/docker'
  assert config['/var/log/ecs/ecs-init.log']['log_group_name'] == prefix + '/var/log/ecs/ecs-init'
  assert config['/var/log/ecs/ecs-agent.log']['log_group_name'] == prefix + '/var/log/ecs/ecs-agent'
