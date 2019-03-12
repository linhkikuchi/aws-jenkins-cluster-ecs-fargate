### Step 1: Run Packer to build AIM for slave, then master
`packer build -var 'aws_access_key=foo' -var 'aws_secret_key=bar' jenkins-slave-packer/jenkins-slave.json`
### Step 2: get AMI from slave and use it to build master
`packer build -var 'aws_access_key=foo' -var 'aws_secret_key=bar' -var 'source_ami=ami' -var 'dds_name=jenkins.abc.com' jenkins-master-packer/jenkins-master.json`
### Step 3: To share AIM, default destination is eu-west-1
#### Note that .boto is required for this module
```pip install --ignore-installed boto3
pip install boto
cat ~/.boto 
[Credentials]
aws_access_key_id = xxx
aws_secret_access_key = xxx
```
`ansible-playbook ansible/ami-share.yaml [--extra-vars "dest_region=eu-west-1"]`

### Step 4: Create ecs cluster by using ecs-cluster/pipeline/Jenkinsfile

### Step 5: To launch jenkins master instance
```  cd terraform-jenkins-master
  python init_tf.py
  python ../ecs-cluster/pipeline/create_bucket.py ${TF_BUCKET_NAME} ${REGION}
  # get eip for slave in SG
  export TF_VAR_jenkins_slave_sg_ip=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=ecs-cluster-eip" --region ap-southeast-1 | jq -r '.Addresses[].PublicIp')
  # get eip for slave in IE
  export TF_VAR_jenkins_slave_ie_ip=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=ecs-cluster-eip" --region eu-west-1 | jq -r '.Addresses[].PublicIp')
  
  terraform init --backend-config="bucket=${TF_BUCKET_NAME}" --backend-config="key=jenkins-launch-template.tfstate" --backend-config="region=ap-southeast-1"
  terraform plan -input=false -out=tfplan
  terraform apply -input=false tfplan```