import boto3
import os
import pytest

# Clients
cfn = boto3.client('cloudformation')
asg = boto3.client('autoscaling')
ec2 = boto3.client('ec2')
ecs = boto3.client('ecs')

# Get physical ECS cluster resource id
def resolve_cluster():
  return cfn.describe_stack_resources(StackName=STACK_NAME,LogicalResourceId=ECS_CLUSTER_NAME)['StackResources'][0]['PhysicalResourceId']

# Get host IP addresses
def resolve_hosts():
  autoscaling_group = cfn.describe_stack_resources(StackName=STACK_NAME,LogicalResourceId=AUTOSCALING_GROUP_NAME)['StackResources'][0]['PhysicalResourceId']
  ec2_instances = [i['InstanceId'] for i in asg.describe_auto_scaling_groups(AutoScalingGroupNames=[autoscaling_group])['AutoScalingGroups'][0]['Instances']]
  ec2_instances_ip = [
    i[IP_ADDRESS_TYPE] 
    for r in ec2.describe_instances(InstanceIds=ec2_instances)['Reservations']
    for i in r['Instances']
  ]
  return (ec2_instances,ec2_instances_ip)

# Variables
STACK_NAME = os.environ['STACK_NAME']
ECS_CLUSTER_NAME = os.environ['ECS_CLUSTER_NAME']
AUTOSCALING_GROUP_NAME = os.environ['AUTOSCALING_GROUP_NAME']
IP_ADDRESS_TYPE = os.environ.get('IP_ADDRESS_TYPE','PrivateIpAddress')
EC2_INSTANCES = resolve_hosts()[0]
HOSTS = resolve_hosts()[1]
ECS_CLUSTER = resolve_cluster()

# Fixtures
@pytest.fixture(scope="session")
def task_definition():
  task_definition = ecs.register_task_definition(
    family='packer-test',
    networkMode='host',
    containerDefinitions=[{'name':'sleep','image':'alpine','cpu':10,'memoryReservation':10,'command':['sleep','20']}])
  family_revision = '%s:%s' % (task_definition['taskDefinition']['family'],task_definition['taskDefinition']['revision'])
  yield family_revision
  ecs.deregister_task_definition(taskDefinition=family_revision)

@pytest.fixture(scope="session")
def ecs_cluster():
  yield resolve_cluster()

@pytest.fixture(scope="session")
def ec2_instances():
  yield EC2_INSTANCES

@pytest.fixture(scope="session")
def ecs_client():
  yield ecs