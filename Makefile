# Project variables
export PROJECT_NAME ?= packer

# AWS security settings
AWS_ROLE ?= arn:aws:iam::429614120872:role/remoteAdmin
AWS_SG_NAME ?= packer-$(firstword $(subst /, ,$(MY_IP_ADDRESS)))-$(TIMESTAMP)
AWS_SG_DESCRIPTION ?= "Temporary security group for Packer"

# Packer settings
export PACKER_VERSION ?= 0.12.3
export AMI_NAME ?= Casecommons ECS Base Image
export AMI_USERS ?=
export AMI_REGIONS ?=
export AWS_INSTANCE_TYPE ?= t2.micro
export AWS_DEFAULT_REGION ?= us-west-2
export AWS_SSH_USERNAME ?= ec2-user
export AWS_SOURCE_AMI ?= ami-f5fc2c8d

# CloudFormation metadata commands
ECS_CLUSTER_QUERY = aws cloudformation describe-stack-resources --stack-name packer-test --query "StackResources[?LogicalResourceId=='ProxyCluster'].PhysicalResourceId" --output text
AUTOSCALING_GROUP_QUERY = aws cloudformation describe-stack-resources --stack-name packer-test --query "StackResources[?LogicalResourceId=='ProxyAutoscalingGroup'].PhysicalResourceId" --output text
EC2_INSTANCE_QUERY = aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?AutoScalingGroupName=='$(AUTOSCALING_GROUP)'].Instances[0].InstanceId" --output text
IP_ADDRESS_QUERY = aws ec2 describe-instances --instance-ids $(EC2_INSTANCE) --query "Reservations[].Instances[].PrivateIpAddress" --output text

# Common settings
include Makefile.settings

.PHONY: release template clean

# Builds image using packer
release:
	@ ${INFO} "Starting packer build..."
	@ $(if $(or $(AWS_PROFILE),$(AWS_DEFAULT_PROFILE)),$(call assume_role,$(AWS_ROLE)),)
	@ $(if $(AWS_CONTAINER_CREDENTIALS_RELATIVE_URI),$(call ecs_credentials),)
	@ ${INFO} "Creating packer security group..."
	@ $(call create_packer_security_group,$(AWS_SG_NAME),$(AWS_SG_DESCRIPTION),$(MY_IP_ADDRESS),$(AWS_VPC_ID))
	@ ${INFO} "Creating packer image..."
	@ docker-compose $(RELEASE_ARGS) build $(PULL_FLAG) packer
	@ ${INFO} "Running packer build..."
	@ docker-compose $(RELEASE_ARGS) up packer
	@ ${INFO} "Deleting packer security group..."
	@ $(call delete_packer_security_group,$(AWS_SG_NAME))
	@ ${INFO} "Deleted packer security group..."
	@ $(call check_exit_code,$(RELEASE_ARGS),packer)
	@ rm -rf build
	@ mkdir -p build
	@ docker cp $$(docker-compose $(RELEASE_ARGS) ps -q packer):/packer/manifest.json build/
	@ docker cp $$(docker-compose $(RELEASE_ARGS) ps -q packer):/packer/build.log build/
	@ $(call transform_manifest,build/manifest.json,build/images.json)
	@ ${INFO} "Build complete"

# Acceptance tests
acceptance:
	@ $(eval export ECS_CLUSTER ?= $(call shell,$(ECS_CLUSTER_QUERY)))
	@ $(eval export AUTOSCALING_GROUP ?= $(call shell,$(AUTOSCALING_GROUP_QUERY)))
	@ $(eval export EC2_INSTANCE ?= $(call shell,$(EC2_INSTANCE_QUERY)))
	@ $(eval export IP_ADDRESS ?= $(call shell,$(IP_ADDRESS_QUERY)))
	@ ${INFO} "Evaluated stack metadata:"
	@ ${INFO} "  Proxy Cluster             -> $(ECS_CLUSTER)"
	@ ${INFO} "  Proxy Auto Scaling Group  -> $(AUTOSCALING_GROUP)"
	@ ${INFO} "  Proxy EC2 Instance        -> $(EC2_INSTANCE)"
	@ ${INFO} "  Proxy Instance IP Address -> $(IP_ADDRESS)"

# Generates packer template to stdout
template:
	@ ${INFO} "Creating packer image..."
	@ docker-compose $(RELEASE_ARGS) build $(PULL_FLAG) packer 2>/dev/null
	@ ${INFO} "Creating packer template..."
	@ docker-compose $(RELEASE_ARGS) run packer cat /packer/packer.json 2>/dev/null
	@ ${INFO} "Template complete"

# Cleans environment
clean:
	${INFO} "Destroying release environment..."
	@ docker-compose $(RELEASE_ARGS) down -v 2>/dev/null || true
	${INFO} "Removing dangling images..."
	@ $(call clean_dangling_images,$(PROJECT_NAME))
	${INFO} "Clean complete"