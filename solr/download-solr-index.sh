#!/bin/bash

# "h" and "help" have no arguments, acting as a flag for help
# "m" and "m5nr" are options with a default value of 10
# "s" and "solr" are options with a default value of 5.0.0
# "t" and "target" are options with a default value of /mnt

# set an initial value for the help flag
HELP=0

# set a default value for options
M5NR_VERSION="10"
SOLR_VERSION="5.0.0"
TARGET="/mnt"

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

set -e
set -x

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
echo "SOLR_VERSION = $SOLR_VERSION"
echo "TARGET = $TARGET"
echo ""

set -e

URL=''
#if [[ $M5NR_VERSION -eq '10' ]] && [[ $SOLR_VERSION -eq '5.0.0' ]]; then
if [ "$M5NR_VERSION" == "10" ] && [ "$SOLR_VERSION" == "5.0.0" ]; then
    URL="http://shock.metagenomics.anl.gov/node/bd7bdbf9-dfba-4794-89e3-6f1bd0b5b9a8?download"
elif [ "$M5NR_VERSION" == "1" ] && [ "$SOLR_VERSION" == "5.0.0" ]; then
    URL="http://shock.metagenomics.anl.gov/node/442aa062-6684-4cbd-ab1b-33b4d1ec5de6?download"
fi  

if [ "$URL" == "" ]; then
    echo "Data index not found for this solr/m5nr version.";
    exit 1;
fi

echo "URL = $URL";

export INDEX_DIR=${TARGET}/m5nr_${M5NR_VERSION}/data/index/
if [ ! -d ${INDEX_DIR} ]; then
  mkdir -p ${INDEX_DIR}
  curl -s "${URL}" | tar -zcvf - -C ${INDEX_DIR}
fi
exit 0;
