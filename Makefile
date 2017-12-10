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
export ECS_AGENT_VERSION ?=
export ECS_RELEASE_VERSION ?=

# Stack metadata settings
export STACK_NAME ?= ami-acceptance
export STACK_OUTPUT_KEY ?= ImageIdOutput
export ECS_CLUSTER_NAME ?= ProxyCluster
export AUTOSCALING_GROUP_NAME ?= ProxyAutoscalingGroup
export IP_ADDRESS_TYPE ?= PublicIpAddress

# Publish commands
AMI_IMAGE_QUERY ?= aws cloudformation describe-stacks --stack-name $(STACK_NAME) --query "Stacks[].Outputs[?OutputKey=='$(STACK_OUTPUT_KEY)'].OutputValue" --output text
COPY_IMAGE ?= aws ec2 copy-image --output text --name "$(AMI_NAME)" --region $(region) --source-image-id $(AMI_IMAGE) --source-region $(AWS_DEFAULT_REGION)
SHARE_IMAGE ?= aws ec2 modify-image-attribute --image-id $(AMI_IMAGE) --launch-permission "{\"Add\":[$${AMI_USERS%?}]}"

# Common settings
include Makefile.settings

.PHONY: build release template clean

# Builds image using packer
build:
	@ ${INFO} "Starting packer build..."
	@ $(if $(or $(AWS_PROFILE),$(AWS_DEFAULT_PROFILE)),$(call assume_role,$(AWS_ROLE)),)
	@ $(if $(AWS_CONTAINER_CREDENTIALS_RELATIVE_URI),$(call ecs_credentials),)
	@ $(if $(and $(S3_BUCKET),$(S3_KEY)),$(call get_images_from_s3))
	@ ${INFO} "Creating packer security group..."
	@ $(call create_packer_security_group,$(AWS_SG_NAME),$(AWS_SG_DESCRIPTION),$(MY_IP_ADDRESS),$(AWS_VPC_ID))
	@ ${INFO} "Creating packer image..."
	@ docker-compose $(BUILD_ARGS) build $(PULL_FLAG) packer
	@ ${INFO} "Running packer build..."
	@ docker-compose $(BUILD_ARGS) up packer
	@ ${INFO} "Deleting packer security group..."
	@ $(call delete_packer_security_group,$(AWS_SG_NAME))
	@ ${INFO} "Deleted packer security group..."
	@ $(call check_exit_code,$(BUILD_ARGS),packer)
	@ mkdir -p build
	@ docker cp $$(docker-compose $(BUILD_ARGS) ps -q packer):/packer/manifest.json build/
	@ docker cp $$(docker-compose $(BUILD_ARGS) ps -q packer):/packer/build.log build/
	@ $(call transform_manifest,build/manifest.json,build/images.json)
	@ ${INFO} "Build complete"

# Runs acceptance tests as part of release process
release:
	@ $(eval export SSH_PRIVATE_KEY)
	@ $(if $(or $(AWS_PROFILE),$(AWS_DEFAULT_PROFILE)),$(call assume_role,$(AWS_ROLE)),)
	@ $(if $(AWS_CONTAINER_CREDENTIALS_RELATIVE_URI),$(call ecs_credentials),)
	@ ${INFO} "Creating acceptance image..."
	@ docker-compose $(RELEASE_ARGS) build $(PULL_FLAG) acceptance
	@ ${INFO} "Running acceptance tests..."
	@ docker-compose $(RELEASE_ARGS) up acceptance
	@ $(call check_exit_code,$(RELEASE_ARGS),acceptance)
	@ mkdir -p build
	@ docker cp $$(docker-compose $(RELEASE_ARGS) ps -q acceptance):/tests/report.xml build/
	@ ${INFO} "Acceptance testing complete"

# Copies and shares AMI to other regions and accounts
publish:
	@ $(eval export AMI_IMAGE ?= $(shell $(AMI_IMAGE_QUERY)))
	@ ${INFO} "Sharing image $(AMI_IMAGE) with accounts: $(AMI_USERS)..."
	@ $(if $(AMI_USERS),$(eval export AMI_USERS=$(foreach user,$(AMI_USERS),{"UserId":"$(user)"},)),)
	@ $(if $(AMI_USERS),$(SHARE_IMAGE),)
	@ ${INFO} "Copying image $(AMI_IMAGE) to regions: $(AMI_REGIONS)..."
	@ $(if $(AMI_REGIONS),$(foreach region,$(AMI_REGIONS),$(COPY_IMAGE);))

# Generates packer template to stdout
template:
	@ ${INFO} "Creating packer image..."
	@ docker-compose $(BUILD_ARGS) build $(PULL_FLAG) packer 2>/dev/null
	@ ${INFO} "Creating packer template..."
	@ docker-compose $(BUILD_ARGS) run packer cat /packer/packer.json 2>/dev/null
	@ ${INFO} "Template complete"

# Cleans environment
clean:
	${INFO} "Destroying build environment..."
	@ docker-compose $(BUILD_ARGS) down -v 2>/dev/null || true
	${INFO} "Destroying release environment..."
	@ docker-compose $(RELEASE_ARGS) down -v 2>/dev/null || true
	${INFO} "Removing dangling images..."
	@ $(call clean_dangling_images,$(PROJECT_NAME))
	${INFO} "Clean complete"