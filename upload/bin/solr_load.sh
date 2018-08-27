#!/bin/bash

## https://github.com/freedev/solr-import-export-json

# set option
HELP=0
IS_NODE=0
INPUT_URI=''
M5NR_VERSION=''
SOLR_URL=''
LOADER='/solr-import-export-json/run.sh'
WORK_DIR='/m5nr_data/Upload'
FILE_PATH=''

function usage {
  echo "Usage: $0 -i <input url> -v <m5nr version> -s <solr url> -l <loader cmd> -d <work dir> [-h -n]"
  echo "   -h help message "
  echo "   -n input uri is shock node "
  echo "   -i input file path or shock url "
  echo "   -v m5nr version "
  echo "   -v solr url "
  echo "   -l loader cmd, default: ${LOADER} "
  echo "   -d work die, default: ${WORK_DIR} "
}

# get options
while getopts hni:v:s:l:d: option; do
    case "${option}"
	in
	    h) HELP=1;;
        n) IS_NODE=1;;
	    i) INPUT_URI=${OPTARG};;
        v) M5NR_VERSION=${OPTARG};;
        s) SOLR_URL=${OPTARG};;
        l) LOADER=${OPTARG};;
        d) WORK_DIR=${OPTARG};;
    esac
done

# check options
if [ "${HELP}" -eq 1 ] || [ -z "${INPUT_URI}" ] || [ -z "${M5NR_VERSION}" ] || [ -z "${SOLR_URL}" ]; then
    usage
    exit 1
fi

# optional download
if [ "${IS_NODE}" -eq 1 ]; then
    echo "downloading ${INPUT_URI} from shock"
    FILE_PATH=${WORK_DIR}/m5nr_v${M5NR_VERSION}.solr.tgz
    curl -s ${INPUT_URI} > ${FILE_PATH}
else
    FILE_PATH=${INPUT_URI}
fi

# extract files
echo "extracting ${FILE_PATH}"
mkdir -p ${WORK_DIR}/solr_extract
tar -zxf ${FILE_PATH} -C ${WORK_DIR}/solr_extract

# create new collection for m5nr version

# load files
for FILE in `ls ${WORK_DIR}/solr_extract`; do
    echo "importing ${FILE} to ${SOLR_URL}"
    ${LOADER} -s ${SOLR_URL} -a import -o ${FILE}
done
echo "done"

