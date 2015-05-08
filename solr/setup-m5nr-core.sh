#!/bin/bash

# set a default values
M5NR_VERSION=10

# binary location from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
BIN=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DEP_CONFIG=${BIN}/deployment.cfg

if [ ! -e ${DEP_CONFIG} ]; then
    echo "source config file ${DEP_CONFIG} not found"
    exit 1
fi

source ${DEP_CONFIG}

echo ""
echo "M5NR_VERSION = $M5NR_VERSION"
echo ""

set -e
set -x

cp -av /opt/solr/server/solr/configsets/sample_techproducts_configs /opt/solr/server/solr/m5nr_${M5NR_VERSION}
echo "name=m5nr_${M5NR_VERSION}" > /opt/solr/server/solr/m5nr_${M5NR_VERSION}/core.properties
cp schema.xml /opt/solr/server/solr/m5nr_${M5NR_VERSION}/conf/schema.xml
cp solr.in.sh /opt/solr/bin
tpage --define data_dir=/mnt/data --define max_bool=100000 solrconfig.xml.tt > /opt/solr/server/solr/m5nr_${M5NR_VERSION}/conf/solrconfig.xml
