FROM alpine:edge

# TODO Figure out which we actually need
RUN apk --no-cache add \
  make \
  gcc \
  g++ \
  openssl-dev \
  bash \
  curl \
  git \
  git-daemon \
  gnupg \
  gzip \
  jq \
  openssh \
  perl \
  tar \
  openssl \
  libstdc++

ADD assets/ /opt/resource/
RUN chmod +x /opt/resource/*

# TODO make image smaller by removing git binaries (see git resource for example)
