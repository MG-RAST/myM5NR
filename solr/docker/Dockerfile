
# M5NR Solr

FROM ubuntu:14.10

RUN apt-get update && apt-get upgrade -y && apt-get install -y \
                libtemplate-perl \
		git \
		curl \
		openjdk-8-jre \
		unzip \
		bc


# install solr
RUN export SOLR_VERSION='5.0.0' && \
  mkdir -p /opt && \
  curl -s http://apache.mirrors.hoobly.com/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz | tar -zxvf - -C /opt/ && \
  ln -s /opt/solr-${SOLR_VERSION} /opt/solr

# configure solr
RUN git clone https://github.com/MG-RAST/myM5NR.git && cd myM5NR/solr && ./install-solr.sh



EXPOSE 8983

# to download solr: ./download-solr-index.sh



# old version

#FROM      ubuntu:14.04
#RUN apt-get update && apt-get upgrade -y && apt-get install -y \
#		libtemplate-perl \
#		git \
#		make \
#		wget
#RUN mkdir -p /kb/runtime/ ; mkdir -p /kb/deployment
#RUN git clone https://github.com/kbase/m5nr.git && \
#	cd /m5nr/ && \
#	make dependencies install-solr config-solr
# now run "make load-solr" or "make load-cached-solr" manually
