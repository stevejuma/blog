FROM alpine
MAINTAINER Steve Juma <dev@ju.ma>

RUN apk --no-cache add \
      ca-certificates \
      curl \
      tar \
      py-pip \
      && pip install s3cmd

ARG hugo_version=0.89.2
RUN curl -sSL https://github.com/gohugoio/hugo/releases/download/v${hugo_version}/hugo_${hugo_version}_Linux-64bit.tar.gz | tar -v -C /usr/local/bin hugo -xz 
CMD [ "hugo" ]
