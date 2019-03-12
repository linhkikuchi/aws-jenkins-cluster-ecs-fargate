FROM centos:latest

ENV HOME /var/jenkins

# install JDK
RUN yum -y install java-1.8.0-openjdk java-1.8.0-openjdk-devel

RUN yum -y install git which

RUN rpm -U --replacepkgs https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
RUN yum -y install curl git which ansible libffi-devl openssl-devel gcc polkit python-pip jq wget fabric unzip
RUN pip install boto3 jinja2 click==6.7 awscli pytest requests ansi2html

RUN wget https://github.com/barnybug/cli53/releases/download/0.8.12/cli53-linux-amd64 -O /usr/local/bin/cli53

#RUN cd /tmp && wget https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip && unzip terraform_0.11.8_linux_amd64.zip -d /usr/local/bin

# install terraform
RUN curl -o terraform.zip `curl https://releases.hashicorp.com/index.json | jq '{terraform}' | grep -v "alpha" | grep -v "beta"|  egrep "linux.*amd64" | sort --version-sort -r | head -1 | awk -F[\"] '{print $4}'`
RUN unzip terraform.zip -d /usr/local/bin
RUN chmod +x /usr/local/bin/terraform

# install packer, latest packer doesn't work properly, use 1.2.5
RUN cd /tmp && wget https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip && unzip packer_1.2.5_linux_amd64.zip -d /usr/local/bin

#RUN curl -o packer.zip `curl https://releases.hashicorp.com/index.json | jq '{packer}' | grep -v "alpha" | grep -v "beta"| egrep "linux.*amd64" | sort --version-sort -r | head -1 | awk -F[\"] '{print $4}'`
#RUN unzip packer.zip -d /usr/local/bin
#RUN chmod +x /usr/local/bin/packer

RUN useradd -d ${HOME} -ms /bin/bash -u 1001 jenkins
# RUN echo "jenkins:w3QW4fzuKKak" | chpasswd

RUN mkdir -p ${HOME}/.ssh
RUN chmod 755 ${HOME}
RUN chown jenkins: ${HOME}
RUN chmod 755 ${HOME}/.ssh
ADD config id_rsa known_hosts authorized_keys ${HOME}/.ssh/
RUN chmod 0600 ${HOME}/.ssh/id_rsa_jenkins_axiom ${HOME}/.ssh/config
RUN chown -R jenkins: ${HOME}/.ssh

# from jenkins slave https://hub.docker.com/r/jenkins/slave/~/dockerfile/
ARG VERSION=3.23

ARG AGENT_WORKDIR=${HOME}/agent

RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

USER jenkins

ENV AGENT_WORKDIR=${AGENT_WORKDIR}
RUN mkdir ${HOME}/.jenkins && mkdir -p ${AGENT_WORKDIR}

VOLUME ${HOME}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR ${HOME}

COPY jenkins-slave /usr/local/bin/jenkins-slave

ENTRYPOINT ["jenkins-slave"]
