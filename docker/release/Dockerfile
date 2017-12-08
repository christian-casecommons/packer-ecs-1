FROM alpine
MAINTAINER Pema Geyleg <pema@casecommons.org>
LABEL application=packer

RUN apk add --no-cache --update curl bash py2-pip openssh-client gcc libffi-dev python-dev musl-dev openssl-dev make

COPY tests/requirements_test.txt /tests/requirements_test.txt
WORKDIR /tests
RUN pip install -r requirements_test.txt

COPY tests /tests
RUN chmod +x /tests/entrypoint.sh

ENTRYPOINT ["/tests/entrypoint.sh"]