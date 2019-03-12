FROM jenkins/jenkins
 
VOLUME /etc/pki/tls
 
# disable setup wizard all together
ENV JAVA_OPTS '-Duser.timezone=Singapore -Djenkins.install.runSetupWizard=false'
USER root

ADD id_rsa_jenkins_axiom config /root/.ssh/
RUN echo "git-codecommit.eu-west-1.amazonaws.com,52.95.112.172 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCWt3RNxyBeoEA79aQJU8808wNXSO30FWcolbeLdicmqCbPUdzWCnDlQP84sTfmZvR92HrpnQNjaT5LKxw206VwGW5OuPIOh0+SCxCS55WrDh567KxZkyBWiJ5TumiUIQDPYbrDOeceCMe5k0n2goMb/qRrtBSeQjw/a5fvamuFlGz3HGEMA7VGQwaqb5cLpLbS6IOx9OTGOc3XuqqKbXHRgZ6swByiJcPjQEHVlJttxkErwBEytPnXyT9ALkuG9UiSVx3MWdKo6XlN6Zc1VmgtOKzDhfmf9u0URtHtRX6791WjCTpAs7JPU1f+gjb01mD4y1yVv+h1JVaeunhkgYDT" >> ~/.ssh/known_hosts
RUN echo "git-codecommit.ap-southeast-1.amazonaws.com,54.240.226.221 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC64UYEX+5l7TJDbMycFNK1Vb9mrJ9urSeDYrIRwacxQrcCcOZfJ4Kim7/yk9j/0K4IM4o5VWGh+sDHxJWnyGWvTc1vUEfiKpEMYg4GoOlRakU7wHYI04IH88EVyp7fBQUYubzWn1sZx2kNHtnAwYkl0e+mbQv9HrxGx6WzbiJa0DbH3s38m/gAPfxurk07SLk4C1H0Piznecp1avl49FDnnJ3FTZzkblKOeZxrmX0RjnZJ35Hi1kwIs3xZSZ9RLRTpI+Rua6BqX4mjZx2KLaDaTYkae3y+lg00LS9cxvQyJmXlGto/0UDqO+Ou8w3NhU7xEmRnciGtI4eW3QQcTcN9" >> ~/.ssh/known_hosts
RUN chmod 600 /root/.ssh/*

RUN apt-get update -y 
RUN apt install jq apache2 supervisor -y
RUN apt install python-pip -y
RUN pip install awscli boto3 pytest requests

RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod headers

# installing ecs-cli
RUN curl -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest
RUN chmod +x /usr/local/bin/ecs-cli

COPY jenkins-apache.conf /etc/apache2/sites-available/000-default.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf

EXPOSE 8080 443

RUN rm -f /etc/localtime \
 && ln -s /usr/share/zoneinfo/Singapore /etc/localtime

VOLUME /var/jenkins_home
CMD ["/usr/bin/supervisord"]