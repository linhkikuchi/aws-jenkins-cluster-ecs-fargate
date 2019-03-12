#!/bin/bash

docker run --name jenkins-master --net="host" \
-v /home/ec2-user/jenkins-home:/var/jenkins_home \
-v /home/ec2-user/war/jenkins.war:/usr/share/jenkins/jenkins.war \
-v /etc/pki/tls:/etc/pki/tls \
--restart always -d jenkins-master