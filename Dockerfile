FROM ubuntu:14.04.2

MAINTAINER Masaki Yoshida

RUN apt-get install -q -y curl wget dnsutils unzip

WORKDIR /usr/local/src

RUN wget -q -O consul.zip https://dl.bintray.com/mitchellh/consul/0.5.0_linux_amd64.zip && \
    unzip consul.zip consul -d /usr/local/bin

RUN wget -q -O consul-template.tar.gz https://github.com/hashicorp/consul-template/releases/download/v0.7.0/consul-template_0.7.0_linux_amd64.tar.gz && \
    tar zxf ./consul-template.tar.gz && \
    mv consul-template_0.7.0_linux_amd64/consul-template /usr/local/bin/consul-template

RUN wget -q -O envconsul.tar.gz https://github.com/hashicorp/envconsul/releases/download/v0.5.0/envconsul_0.5.0_linux_amd64.tar.gz && \
    tar zxf ./envconsul.tar.gz && \
    mv ./envconsul_0.5.0_linux_amd64/envconsul /usr/local/bin/envconsul

WORKDIR /
