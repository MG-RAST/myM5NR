#!/bin/bash

# "h" and "help" have no arguments, acting as a flag for help
# "m" and "m5nr" are options with a default value of 10

# set an initial value for the help flag
HELP=0

# set a default value for options
M5NR_VERSION=10

# read the options
TEMP=`getopt -o hm:s: --long help,m5nr:,solr: -n ${BASH_SOURCE[0]} -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -h|--help) HELP=1 ; shift ;;
        -m|--m5nr)
            case "$2" in
                *) M5NR_VERSION=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ $HELP -eq 1 ]; then
    echo "Usage: $0 [-h] [-m m5nr_version]";
    exit 0;
fi

# binary location from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
BIN=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DEP_CONFIG=${BIN}/../deployment.cfg

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
