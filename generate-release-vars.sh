#!/usr/bin/env bash
set -eio pipefail

usage() {
    echo "Usage:"
    echo "  $0 ECS_INIT_VERSION AMI_VERSION"
    echo "Example:"
    echo "  $0 1.55.0-1 20210902"
}

error() {
    local msg="$1"
    echo "ERROR: $msg"
    usage
    exit 1
}

readonly ecs_init_version="$1"
if [ -z "$ecs_init_version" ]; then
    error "ecs-init version is required."
fi
readonly ami_version="$2"
if [ -z "$ami_version" ]; then
    error "ami version is required."
fi

agent_version=$(echo "$ecs_init_version" | awk -F "-" '{ print $1 }')
ecs_init_rev=$(echo "$ecs_init_version" | awk -F "-" '{ print $2 }')
readonly agent_version ecs_init_rev
if [ -z "$ecs_init_rev" ]; then
    error "ecs-init rev was empty, did you forget the dash in ECS_INIT_VERSION? ie, 1.55.0-1"
fi
if [ -z "$agent_version" ]; then
    error "agent version was empty, seems that your ECS_INIT_VERSION was malformed, it should look like: 1.55.0-1"
fi

# this can be any region, as we use it to grab the latest AL2 AMI name so it should be the same across regions.
readonly region="us-west-2"

set -x

# get the latest source AMI names
ami_id_x86=$(aws ssm get-parameters --region "$region" --names /aws/service/ami-amazon-linux-latest/amzn2-ami-minimal-hvm-x86_64-ebs --query 'Parameters[0].[Value]' --output text)
ami_name_x86=$(aws ec2 describe-images --region "$region" --owner amazon --image-id "$ami_id_x86" --query 'Images[0].Name' --output text)
ami_id_arm=$(aws ssm get-parameters --region "$region" --names /aws/service/ami-amazon-linux-latest/amzn2-ami-minimal-hvm-arm64-ebs --query 'Parameters[0].[Value]' --output text)
ami_name_arm=$(aws ec2 describe-images --region "$region" --owner amazon --image-id "$ami_id_arm" --query 'Images[0].Name' --output text)
ami_id_al1=$(aws ssm get-parameters --region "$region" --names /aws/service/ami-amazon-linux-latest/amzn-ami-minimal-hvm-x86_64-ebs --query 'Parameters[0].[Value]' --output text)
ami_name_al1=$(aws ec2 describe-images --region "$region" --owner amazon --image-id "$ami_id_al1" --query 'Images[0].Name' --output text)
readonly ami_name_arm ami_name_x86 ami_name_al1

cat >|release.auto.pkrvars.hcl <<EOF
ami_version        = "$ami_version"
source_ami_al2     = "$ami_name_x86"
source_ami_al2arm  = "$ami_name_arm"
ecs_agent_version  = "$agent_version"
ecs_init_rev       = "$ecs_init_rev"
docker_version     = "20.10.7"
containerd_version = "1.4.6"
source_ami_al1     = "$ami_name_al1"
EOF
