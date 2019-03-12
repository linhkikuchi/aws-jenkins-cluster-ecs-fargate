#!/bin/bash
instance_metadata=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/jenkins-role/)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
AWS_ACCESS_KEY_ID=$(echo ${instance_metadata} | jq -r .AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo ${instance_metadata} | jq -r .SecretAccessKey)
AWS_SESSION_TOKEN=$(echo ${instance_metadata} | jq -r .Token)
AWS_CLI_PROFILE="jenkins"
aws configure --profile ${AWS_CLI_PROFILE} set aws_access_key_id ${AWS_ACCESS_KEY_ID}
aws configure --profile ${AWS_CLI_PROFILE} set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
aws configure --profile ${AWS_CLI_PROFILE} set aws_session_token ${AWS_SESSION_TOKEN}
aws configure --profile ${AWS_CLI_PROFILE} set region ${REGION}

# get backup/release from s3
INSTANCE_ID=$(ec2-metadata | grep 'instance-id:' | head -1 | cut -d ' ' -f 2)
BUCKET=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=data-bucket" --region=$REGION --output=text | cut -f5)
PUBLIC_HOSTNAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=public-hostname" --region=$REGION --output=text | cut -f5)
echo "PUBLIC_HOSTNAME ${PUBLIC_HOSTNAME}"
RELEASE_VERSION=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=release-version" --region=$REGION --output=text | cut -f5)

aws s3 cp s3://${BUCKET}/jenkins-backup.tar.gz /home/ec2-user/jenkins-home/jenkins-backup.tar.gz
cd /home/ec2-user/jenkins-home && tar xvzf jenkins-backup.tar.gz && rm -rf jenkins-backup.tar.gz

mkdir -p /home/ec2-user/war && cd /home/ec2-user/war && wget https://updates.jenkins-ci.org/latest/jenkins.war
chown -R ec2-user:ec2-user /home/ec2-user

#start jenkins master container
docker run --name jenkins-master --net="host" \
-v /home/ec2-user/jenkins-home:/var/jenkins_home \
-v /home/ec2-user/war/jenkins.war:/usr/share/jenkins/jenkins.war \
-v /etc/pki/tls:/etc/pki/tls \
--restart always -d jenkins-master

#create swap
dd if=/dev/zero of=/mnt/4GB.swap bs=1M count=4096
mkswap /mnt/4GB.swap
chmod 600 /mnt/4GB.swap
swapon /mnt/4GB.swap

# Get the private and public hostname from EC2 resource tags
# Get the local and public IP Address that is assigned to the instance
LOCAL_IPV4=$(ec2-metadata | grep 'local-ipv4:' | head -1 | cut -d ' ' -f 2)
PUBLIC_IPV4=$(ec2-metadata | grep 'public-ipv4:' | head -1 | cut -d ' ' -f 2)

#associate with elastic IP
EIPALLOC=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=allocation-id" --region=$REGION --output=text | cut -f5)
aws ec2 associate-address --allocation-id "$EIPALLOC" --instance-id "$INSTANCE_ID" --allow-reassociation --private-ip-address "$LOCAL_IPV4" --region "$REGION"

# update route53 entry
ZONE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=zone-id" --region=$REGION --output=text | cut -f5)

# The TimeToLive in seconds we use for the DNS records 
TTL="300"

# update DNS
# Create a new or update the A-Records on Route53 with public and private IP address
INTERNAL_HOSTNAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=internal-hostname" --region=$REGION --output=text | cut -f5)
EIP=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=eip" --region=$REGION --output=text | cut -f5)

/usr/local/bin/cli53 rrcreate --replace "$ZONE" "$INTERNAL_HOSTNAME $TTL A $LOCAL_IPV4"
/usr/local/bin/cli53 rrcreate --replace "$ZONE" "$PUBLIC_HOSTNAME $TTL A $EIP"
