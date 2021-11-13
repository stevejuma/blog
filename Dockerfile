FROM alpine
MAINTAINER Steve Juma <dev@ju.ma>

RUN apk --no-cache add \
      ca-certificates \
      curl \
      tar \
      py-pip \
      && pip install s3cmd

ENV HUGO_VERSION 0.89.2
RUN curl -sSL https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz | tar -v -C /usr/local/bin hugo -xz 

# Setup s3cmd config
RUN { \
      echo '[default]'; \
      echo 'access_key=$AWS_ACCESS_KEY'; \
      echo 'secret_key=$AWS_SECRET_KEY'; \
      } > ~/.s3cfg

WORKDIR /usr/src/blog/

# add files
COPY . /usr/src/blog/

CMD [ "./release.sh" ]
