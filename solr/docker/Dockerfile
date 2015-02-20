
# M5NR Solr

FROM      ubuntu:14.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
		libtemplate-perl \
		git \
		make \
		wget

RUN mkdir -p /kb/runtime/ ; mkdir -p /kb/deployment

RUN git clone https://github.com/kbase/m5nr.git

