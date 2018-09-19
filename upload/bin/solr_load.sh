#!/bin/bash

## https://github.com/freedev/solr-import-export-json

# set option
HELP=0
IS_NODE=0
INPUT_URI=''
M5NR_VERSION=''
SOLR_URL=''
SOLR_CONTAINER='solr-m5nr'
LOADER='/solr-import-export-json'
WORK_DIR='/m5nr_data/Upload'
FILE_PATH=''

function usage {
  echo "Usage: $0 -i <input url> -v <m5nr version> -s <solr url> [-c <solr container> -l <loader cmd> -d <work dir> -h -n]"
  echo "   -h help message "
  echo "   -n input uri is shock node "
  echo "   -i input file path or shock url "
  echo "   -v m5nr version "
  echo "   -s solr url "
  echo "   -l loader cmd, default: ${LOADER} "
  echo "   -d work dir, default: ${WORK_DIR} "
}

# get options
while getopts hni:v:s:c:l:d: option; do
    case "${option}"
	in
	    h) HELP=1;;
        n) IS_NODE=1;;
	    i) INPUT_URI=${OPTARG};;
        v) M5NR_VERSION=${OPTARG};;
        s) SOLR_URL=${OPTARG};;
        c) SOLR_CONTAINER=${OPTARG};;
        l) LOADER=${OPTARG};;
        d) WORK_DIR=${OPTARG};;
    esac
done

# check options
if [ "${HELP}" -eq 1 ] || [ -z "${INPUT_URI}" ] || [ -z "${M5NR_VERSION}" ] || [ -z "${SOLR_URL}" ]; then
    usage
    exit 0
fi

mkdir -p ${WORK_DIR}

# optional download
if [ "${IS_NODE}" -eq 1 ]; then
    echo "downloading ${INPUT_URI} from shock"
    FILE_PATH=${WORK_DIR}/m5nr.solr.tgz
    curl -s ${INPUT_URI} > ${FILE_PATH}
else
    FILE_PATH=${INPUT_URI}
fi

# extract files
echo "extracting ${FILE_PATH}"
mkdir -p ${WORK_DIR}/solr_extract
tar -zxf ${FILE_PATH} -C ${WORK_DIR}/solr_extract

# create new collection / config for m5nr version
# must have docker socket mounted: -v "/var/run/docker.sock:/var/run/docker.sock" and docker installed: docker_setup.sh
echo "creating collection for m5nr_${M5NR_VERSION}"
/usr/bin/docker exec ${SOLR_CONTAINER} bash -c "cd /MG-RAST-infrastructure/ && git pull && cd services/solr-m5nr && ./setup-m5nr-core.sh ${M5NR_VERSION}"
/usr/bin/docker exec ${SOLR_CONTAINER} /opt/solr/bin/solr create -c m5nr_${M5NR_VERSION}
SOLR_URL=${SOLR_URL}/m5nr_${M5NR_VERSION}

# load files
cd ${LOADER}
for FILE in `ls ${WORK_DIR}/solr_extract`; do
    START=`date +"%Y%m%d.%H%M"`
    echo "$START - importing ${FILE} to ${SOLR_URL}"
    ./run.sh -s ${SOLR_URL} -a import -o ${FILE}
    END=`date +"%Y%m%d.%H%M"`
    echo "$END - done"
done

