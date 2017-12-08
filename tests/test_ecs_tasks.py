import boto3
from .conftest import HOSTS
testinfra_hosts = HOSTS

def test_start_and_stop_ecs_task(ecs_client, task_definition, ecs_cluster):
  start_result = ecs_client.run_task(cluster=ecs_cluster, taskDefinition=task_definition)
  task_arn = start_result['tasks'][0]['taskArn']
  assert not start_result['failures']
  assert start_result['tasks']
  assert start_result['tasks'][0]['lastStatus'] == 'PENDING'
  stop_result = ecs_client.stop_task(cluster=ecs_cluster, task=task_arn, reason='pytest')
  waiter = ecs_client.get_waiter('tasks_stopped')
  waiter.wait(
    cluster=ecs_cluster,
    tasks=[stop_result['task']['taskArn']],
    WaiterConfig={'Delay': 6, 'MaxAttempts': 10})
  result = ecs_client.describe_tasks(cluster=ecs_cluster, tasks=[task_arn])
  assert result['tasks'][0]['lastStatus'] == 'STOPPED'
  assert result['tasks'][0]['stoppedReason'] == 'pytest'

def test_run_ecs_task(ecs_client, task_definition, ecs_cluster):
  start_result = ecs_client.run_task(
    cluster=ecs_cluster, 
    taskDefinition=task_definition,
    overrides={'containerOverrides': [{'name': 'sleep','command': ['true','1']}]}
  )
  waiter = ecs_client.get_waiter('tasks_stopped')
  waiter.wait(
    cluster=ecs_cluster,
    tasks=[start_result['tasks'][0]['taskArn']],
    WaiterConfig={'Delay': 6, 'MaxAttempts': 10})
  result = ecs_client.describe_tasks(cluster=ecs_cluster, tasks=[start_result['tasks'][0]['taskArn']])
  assert result['tasks'][0]['lastStatus'] == 'STOPPED'
  assert result['tasks'][0]['containers'][0]['exitCode'] == 0