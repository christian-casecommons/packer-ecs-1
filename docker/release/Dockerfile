FROM alpine
MAINTAINER Pema Geyleg <pema@casecommons.org>
ARG project_name
LABEL application=${project_name}

RUN echo "http://nl.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories && \
    apk add --no-cache --update curl bash jq confd py2-pip && \
    pip install awscli && \
    curl -L https://releases.hashicorp.com/packer/0.12.0/packer_0.12.0_linux_amd64.zip -o /packer.zip && \
    unzip /packer.zip -d /usr/bin && \
    rm /packer.zip

COPY src/etc/confd /etc/confd
COPY src /packer
WORKDIR /packer

ENTRYPOINT ["/packer/entrypoint.sh"]
CMD ["packer", "build", "packer.json"]