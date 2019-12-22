FROM ubuntu:xenial

RUN apt-get update && apt-get install -y apt-utils jq curl

COPY ensure-files.sh /ensure-files.sh

WORKDIR /