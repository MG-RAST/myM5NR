
# M5NR Solr

FROM      ubuntu:14.04

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
		libtemplate-perl \
		git \
		make \
		wget

RUN mkdir -p /kb/runtime/ ; mkdir -p /kb/deployment

RUN git clone https://github.com/kbase/m5nr.git && \
	cd /m5nr/ && \
	make dependencies install-solr config-solr

# now run "make load-solr" or "make load-cached-solr" manually