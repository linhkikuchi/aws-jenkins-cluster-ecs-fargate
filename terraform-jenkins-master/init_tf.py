import os
import base64

with open("jenkins-master-userdata.sh", "rb") as file:
    user_data = base64.b64encode(file.read())

# eip = os.environ["EIP"]
# sg_id = os.environ["SG_ID"]
ami_id = os.environ["AMI_ID"]
key_name = os.environ["KEY_NAME"]
dns_name = os.environ["DNS_NAME"]
server_name = dns_name.split('.')[0]
# allocation_id = os.environ["ALLOCATION_ID"]
zone_id = os.environ["ZONE_ID"]
jenkins_backup_bucket = os.environ["JENKINS_BACKUP_BUCKET"]
release_version = os.environ["RELEASE_VERSION"]


if __name__ == "__main__":

    with open("terraform.tfvars", "w") as this_file:
        this_file.write("user_data = \""+user_data+"\"\n")
        # this_file.write("eip = \""+eip+"\"\n")
        # this_file.write("sg_id = \""+sg_id+"\"\n")
        this_file.write("ami_id = \""+ami_id+"\"\n")
        this_file.write("key_name = \""+key_name+"\"\n")
        this_file.write("dns_name = \""+dns_name+"\"\n")
        this_file.write("server_name = \""+server_name+"\"\n")
        # this_file.write("allocation_id = \""+allocation_id+"\"\n")
        this_file.write("zone_id = \""+zone_id+"\"\n")
        this_file.write("jenkins_backup_bucket = \""+jenkins_backup_bucket+"\"\n")
        this_file.write("release_version = \""+release_version+"\"")
