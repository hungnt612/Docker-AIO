FROM docker:24.0.2-dind-rootless

ENV HOME /home/rootless
ENV COMPLETIONS /usr/share/bash-completion/completions

COPY .bashrc $HOME/.bashrc
COPY .bash_completion $HOME/.bash_completion
COPY .nanorc $HOME/.nanorc
RUN mkdir $HOME/.kube

USER root
# this is the config file for k8s
COPY config $HOME/.kube/config
RUN chmod o-r $HOME/.kube/config
RUN chmod g-r $HOME/.kube/config
ENV KUBECONFIG $HOME/.kube/config

# this YAML can be used to apply patches needed to open ports for ingresses under Kind
# if you create a cluster without referring to this file you'll later need to apply them manually
# it is recommended to add the flag --config=/root/config.yml when creating new clusters
COPY config.yml $HOME/config.yml
# you will also need to deploy one of the available ingress controllers that will listen on 80/443 ports
# check this document to learn how to deploy them:
# NGINX: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx
# Contour: https://kind.sigs.k8s.io/docs/user/ingress/#contour
# Kong: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-kong

# helper script that installs k8s clusters and deploys nginx ingress controllers
COPY create_cluster.sh $HOME/create_cluster.sh
RUN chmod +x $HOME/create_cluster.sh

# basic stuff
RUN	apk add --no-cache \
	bash \
	bash-completion \
	ca-certificates \
	gcc \
	git \
	make \
	musl-dev \
	zip \
	nano \
	nano-syntax \
	vim \
	lynx \
	htop \
	wget \
	curl \
	apache2-ssl \
	apache2-utils \
	ncurses \
	go \
	python3 \
	jq \
	openssl \
  perl


RUN apk add --no-cache vault libcap
RUN setcap cap_ipc_lock= /usr/sbin/vault
RUN apk add --no-cache python3 py3-pip
RUN pip install msal
RUN pip install python-sonarqube-api==1.3.7.post0

# Docker
# https://www.docker.com/
#ENV DOCKER_VERSION 20.10.24
#RUN apk add --no-cache \
#	docker=${DOCKER_VERSION}
# kubectl
# https://kubernetes.io/docs/reference/kubectl/
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl \
	-s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/bin/kubectl
RUN kubectl completion bash > $COMPLETIONS/kubectl.bash

# kubecolor
RUN go install github.com/hidetatz/kubecolor/cmd/kubecolor@latest

# stern
RUN go install github.com/stern/stern@latest

# helm
# https://helm.sh/
ENV HELM_VERSION 3.11.3
RUN curl -LO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
RUN tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
RUN chmod +x linux-amd64/helm
RUN mv linux-amd64/helm /usr/bin/helm
RUN helm completion bash > $COMPLETIONS/helm.bash
RUN rm -rf helm-v${HELM_VERSION}-linux-amd64.tar.gz linux-amd64

# terraform
# https://www.terraform.io/
ENV TF_VERSION 1.4.5
RUN curl -LO https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
RUN unzip -x terraform_${TF_VERSION}_linux_amd64.zip
RUN chmod +x terraform
RUN mv ./terraform /usr/bin/terraform
RUN rm terraform_${TF_VERSION}_linux_amd64.zip

# skaffold
# https://skaffold.dev/
RUN curl -Lo /usr/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
RUN chmod +x /usr/bin/skaffold

# kubeseal
ENV KUBESEAL_VERSION 0.20.2
RUN mkdir ./kubeseal_install && cd ./kubeseal_install
RUN curl -LO https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
RUN tar -zxvf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
RUN chmod +x ./kubeseal
RUN mv ./kubeseal /usr/bin/kubeseal && cd ..
RUN rm -rf kubeseal_install

# kind
# https://kind.sigs.k8s.io/
ENV KIND_VERSION 0.18.0
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64
RUN chmod +x ./kind
RUN mv ./kind /usr/bin/kind

# kubectl's plugin manager krew
# https://krew.sigs.k8s.io/
ENV KREW_VERSION 0.4.3
RUN mkdir /tmp/krew \
	&& cd /tmp/krew \
	&& curl -fsSL https://github.com/kubernetes-sigs/krew/releases/download/v${KREW_VERSION}/krew-linux_amd64.tar.gz \
	| tar -zxf- \
	&& ./krew-linux_amd64 install krew \
	&& cd \
	&& rm -rf /tmp/krew \
	&& echo export 'PATH=$HOME/.krew/bin:$PATH' >> .bashrc

# kubectx and kubens for k8s
# https://github.com/ahmetb/kubectx
RUN cd /tmp \
	&& git clone https://github.com/ahmetb/kubectx \
	&& cd kubectx \
	&& mv kubectx /usr/bin/kubectx \
	&& mv kubens /usr/bin/kubens \
	&& mv completion/*.bash $COMPLETIONS \
	&& cd .. \
	&& rm -rf kubectx

#ROXCTL

RUN curl -O https://mirror.openshift.com/pub/rhacs/assets/4.0.2/bin/Linux/roxctl
RUN mv roxctl /usr/bin/roxctl
RUN  chmod +x /usr/bin/roxctl

RUN apk add --update ca-certificates
RUN apk add --no-cache --virtual .build-deps \
        curl \
        tar \
    && curl --retry 7 -Lo /tmp/client-tools.tar.gz "https://mirror.openshift.com/pub/openshift-v3/clients/3.7.23/linux/oc.tar.gz"

RUN tar zxf /tmp/client-tools.tar.gz -C /usr/local/bin oc \
    && rm /tmp/client-tools.tar.gz \
    && apk del .build-deps

RUN apk add --update ca-certificates
RUN mkdir -p /etc/docker && mkdir -p /etc/docker/certs.d
RUN chmod 777 -R /etc/docker
RUN chmod -R 777 /usr/local/share/ca-certificates
RUN chmod -R 777 /etc/ssl/certs

# Configure sonar version
ENV SONAR_SCANNER_VERSION=4.6.2.2472

# Install dependencies
RUN apk add --no-cache \
  ca-certificates \
  curl \
  unzip \
  libc6-compat \
  openjdk8-jre

# Download sonar scanner
RUN mkdir -p /opt
RUN curl -fSL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip \
  -o /opt/sonar-scanner.zip

# Unzip file and remove zip
RUN unzip -qq /opt/sonar-scanner.zip -d /opt
RUN mv /opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux /sonar-scanner
RUN rm /opt/sonar-scanner.zip

# Set symlink
RUN ln -s /sonar-scanner/bin/sonar-scanner /bin/sonar-scanner

# [WORKAROUND] Configure sonar-scanner to use system jre
RUN sed -i 's/use_embedded_jre=true/use_embedded_jre=false/g' /sonar-scanner/bin/sonar-scanner

RUN mkdir -p /sonar-report
COPY sonar-cnes-report-4.2.0.jar /sonar-cnes-report-4.2.0.jar
RUN chmod -R 777 /sonar-report

ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk
RUN apk add --no-cache --virtual build-dependencies wget unzip gnupg; \
    apk add --no-cache git python3 py-pip bash shellcheck 'nodejs>12' openjdk11-jre curl musl-locales musl-locales-lang;

# Install AWS cli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install -i /usr/local/aws-cli -b /usr/local/bin

# Install minio cli
RUN  wget https://dl.min.io/client/mc/release/linux-amd64/mc
RUN mv mc /usr/local/bin
RUN chmod +x /usr/local/bin/mc

#RUN chown -R rootless:rootless /home/rootless
#USER rootless
USER root
ENTRYPOINT [ "bash" ]
