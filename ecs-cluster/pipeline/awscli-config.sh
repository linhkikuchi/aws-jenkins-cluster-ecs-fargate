#!/bin/bash -ex
rm -rf .terraform
rm -rf ~/.aws/credentials
set +x
instance_metadata=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/${JENKINS_ROLE}/)
AWS_ACCESS_KEY_ID=$(echo ${instance_metadata} | jq -r .AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo ${instance_metadata} | jq -r .SecretAccessKey)
AWS_SESSION_TOKEN=$(echo ${instance_metadata} | jq -r .Token)

aws configure --profile ${SST_AWS_PROFILE} set aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure --profile ${SST_AWS_PROFILE} set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
aws configure --profile ${SST_AWS_PROFILE} set aws_session_token ${AWS_SESSION_TOKEN}
set -x
export ENVIRONMENT_AWS_ACCOUNT_ID=$1

export IAM_ROLE_ARN_TARGET="arn:aws:iam::"${ENVIRONMENT_AWS_ACCOUNT_ID}":role/"${ROLE_ON_TARGET_ACCOUNT}
set +x
echo "Switch to IAM Role: "${IAM_ROLE_ARN_TARGET}
assume_role_output=$(aws sts assume-role --profile ${SST_AWS_PROFILE} --role-arn ${IAM_ROLE_ARN_TARGET} --role-session-name terraform --duration-seconds 3600)
AWS_ACCESS_KEY_ID=$(echo ${assume_role_output} | jq -r .Credentials.AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo ${assume_role_output} | jq -r .Credentials.SecretAccessKey)
AWS_SESSION_TOKEN=$(echo ${assume_role_output} | jq -r .Credentials.SessionToken)

aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
aws configure set aws_session_token ${AWS_SESSION_TOKEN}
set -x
aws configure set region ${REGION}
