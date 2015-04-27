#!/bin/bash

# "h" and "help" have no arguments, acting as a flag for help
# "m" and "m5nr" are options with a default value of 10
# "s" and "solr" are options with a default value of 5.0.0
# "t" and "target" are options with a default value of /mnt

# set an initial value for the help flag
HELP=0

# set a default value for options
M5NR_VERSION=10
SOLR_VERSION='5.0.0'
TARGET='/mnt'

# read the options
TEMP=`getopt -o hm:s: --long help,m5nr:,solr: -n 'install-solr.sh' -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -h|--help) HELP=1 ; shift ;;
        -m|--m5nr)
            case "$2" in
                *) M5NR_VERSION=$2 ; shift 2 ;;
            esac ;;
        -s|--solr)
            case "$2" in
                *) SOLR_VERSION=$2 ; shift 2 ;;
            esac ;;
        -t|--target)
            case "$2" in
                *) TARGET=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ $HELP -eq 1 ]; then
    echo "Usage: $0 [-h] [-m m5nr_version] [-s solr_version]";
    exit 0;
fi

echo ""
echo "M5NR_VERSION = $M5NR_VERSION"
echo "SOLR_VERSION = $SOLR_VERSION"
echo "TARGET = $TARGET"
echo ""

set -e
set -x

wget http://apache.mirrors.hoobly.com/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz
tar zxvf solr-${SOLR_VERSION}.tgz /opt
cp -av /opt/solr/server/solr/configsets/sample_techproducts_configs /opt/solr/server/solr/m5nr_${M5NR_VERSION}
echo "name=m5nr_$(M5NR_VERSION)" > /opt/solr/server/solr/m5nr_$(M5NR_VERSION)/core.properties
cp schema.xml /opt/solr/server/solr/m5nr_${M5NR_VERSION}/conf/schema.xml
tpage --define data_dir=/mnt/data --define max_bool=100000 solrconfig.xml.tt > /opt/solr/server/solr/m5nr_$(M5NR_VERSION)/conf/solrconfig.xml
