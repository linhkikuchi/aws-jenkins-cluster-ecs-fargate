#!/bin/bash -ex

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/al2ami.html
cd ecs-cluster/terraform
rm -rf .terraform

export TF_VAR_region=${REGION}
export TF_VAR_ecs_cluster_name=${ECS_CLUSTER_NAME}
export TF_VAR_instance_type=${INSTANCE_TYPE}
export TF_VAR_spot_price=${SPOT_PRICE}
export JOB=$1
export TF_VAR_key_name="${KEY_NAME}"
export TF_VAR_ecs_ami_id="ami-0651de2fa6ccf6d26"
export TF_STATE_BUCKET="jenkins-state-tf"

esac

echo "#!/bin/bash -xe
echo ECS_CLUSTER=${ECS_CLUSTER_NAME} >> /etc/ecs/ecs.config
sudo dd if=/dev/zero of=/mnt/4GB.swap bs=1M count=4096
sudo mkswap /mnt/4GB.swap
sudo chmod 600 /mnt/4GB.swap
sudo swapon /mnt/4GB.swap" > user_data.sh

USER_DATA=$(base64 user_data.sh)
export TF_VAR_user_data=${USER_DATA}
python ../pipeline/create_bucket.py ${TF_STATE_BUCKET} ${REGION}

terraform init --backend-config="bucket=${TF_STATE_BUCKET}" --backend-config="region=${REGION}"
if [ "${JOB}" == "deploy" ] ; then
	terraform plan -input=false -out=tfplan
else
	terraform plan -destroy -input=false -out=tfplan
fi
