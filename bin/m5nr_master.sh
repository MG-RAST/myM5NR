#!/bin/bash

# set option
HELP=0
ACTION=''
TOKEN=''
PROCS=4
M5NR_VERSION=''
SOURCE_CONFIG='/myM5NR/sources.yaml'
BUILD_CONFIG='/myM5NR/build.yaml'
UPLOAD_CONFIG='/myM5NR/upload.yaml'
COMPILER='/myM5NR/bin/m5nr_compiler.py'
UPLOADER='/myM5NR/bin/shock_upload.py'

function usage {
  echo "Usage: $0 -a <action> -t <token> -p <procs> -s <source config> -b <build config> -u <upload config> -c <m5nr_compiler.py> -v <m5nr version> [-h <help>] "
  echo "   -h <help>  "
  echo "   -a (download|parse|build|upload) "
  echo "   -t mg-rast token for shock upload "
  echo "   -p <# of threads to use> "
  echo "   -s sources.yaml file, default ${SOURCE_CONFIG} "
  echo "   -b build.yaml file, default ${BUILD_CONFIG} "
  echo "   -u upload.yaml file, default ${UPLOAD_CONFIG} "
  echo "   -c /path/to/m5nr_compiler.py, default ${COMPILER} "
  echo "   -v m5nr version "
  echo "Note: run this in base /m5nr_data dir"
}

# get options
while getopts ha:t:p:s:b:u:c:v: option; do
    case "${option}"
	in
	    h) HELP=1;;
	    a) ACTION=${OPTARG};;
        a) TOKEN=${OPTARG};;
	    p) PROCS=${OPTARG};;
	    s) SOURCE_CONFIG=${OPTARG};;
	    b) BUILD_CONFIG=${OPTARG};;
        u) UPLOAD_CONFIG=${OPTARG};;
        c) COMPILER=${OPTARG};;
        v) M5NR_VERSION=${OPTARG};;
    esac
done

# check options
if [ "${HELP}" -eq 1 ] || [ -z "${ACTION}" ]; then
    usage
    exit 0
fi

# make sure directeries exist or else compiler fails
mkdir -p Sources Parsed Build

# run actions
if [ "${ACTION}" == "download" ] || [ "${ACTION}" == "parse" ]; then
    if [ ! -e "${SOURCE_CONFIG}" ]; then
        echo "download / parse actions requires sources.yaml file"
        usage
        exit 1
    fi
    
    SOURCES=`grep '^[A-Za-z]' ${SOURCE_CONFIG} | cut -f1 -d':'`
    
    if [ "${ACTION}" == "download" ]; then
        echo "Downloading Started: "`date +"%Y%m%d.%H%M"`
        echo ${SOURCES} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} download -f -d -s {}
        echo "Downloading Completed: "`date +"%Y%m%d.%H%M"`
    elif [ "${ACTION}" == "parse" ]; then
        FIRST_LIST=()
        SECOND_LIST=()
        THIRD_LIST=()
        
        for SRC in `echo ${SOURCES}`; do
            RANK=`yq r ${SOURCE_CONFIG} ${SRC}.rank`
            if [ "${RANK}" -eq "1" ]; then
                FIRST_LIST+=(${SRC})
            elif [ "${RANK}" -eq "2" ]; then
                SECOND_LIST+=(${SRC})
            elif [ "${RANK}" -eq "3" ]; then
                THIRD_LIST+=(${SRC})
            fi
        done
        
        echo "Parsing Started: "`date +"%Y%m%d.%H%M"`
        echo "Parsing ${FIRST_LIST[@]}"
        echo ${FIRST_LIST[@]} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} parse -d -f -s {}
        echo "Parsing ${SECOND_LIST[@]}"
        echo ${SECOND_LIST[@]} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} parse -d -f -s {}
        echo "Parsing ${THIRD_LIST[@]}"
        echo ${THIRD_LIST[@]} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} parse -d -f -s {}
        echo "Parsing Completed: "`date +"%Y%m%d.%H%M"`
    fi
elif [ "${ACTION}" == "build" ] ; then
    if [ ! -e "${BUILD_CONFIG}" ]; then
        echo "build action requires build.yaml file"
        usage
        exit 1
    fi
    if [ "${M5NR_VERSION}" == "" ]; then
        echo "build action requires m5nr version"
        usage
        exit 1
    fi
    
    TOTAL=`grep '^- name:' ${BUILD_CONFIG} | wc -l`
    TOTAL=$((TOTAL-1))
    
    FIRST_LIST=()
    SECOND_LIST=()
    THIRD_LIST=()
    
    for POS in `seq 0 ${TOTAL}`; do
        NAME=`yq r ${BUILD_CONFIG} "[${POS}].name"`
        RANK=`yq r ${BUILD_CONFIG} "[${POS}].rank"`
        if [ "${RANK}" -eq "1" ]; then
            FIRST_LIST+=(${NAME})
        elif [ "${RANK}" -eq "2" ]; then
            SECOND_LIST+=(${NAME})
        elif [ "${RANK}" -eq "3" ]; then
            THIRD_LIST+=(${NAME})
        fi
    done
    
    echo "Building Started: "`date +"%Y%m%d.%H%M"`
    echo "Building ${FIRST_LIST[@]}"
    echo ${FIRST_LIST[@]} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} build -v ${M5NR_VERSION} -d -f -a {}
    echo "Building ${SECOND_LIST[@]}"
    echo ${SECOND_LIST[@]} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} build -v ${M5NR_VERSION} -d -f -a {}
    echo "Building ${THIRD_LIST[@]}"
    echo ${THIRD_LIST[@]} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} build -v ${M5NR_VERSION} -d -f -a {}
    echo "Building Completed: "`date +"%Y%m%d.%H%M"`
elif [ "${ACTION}" == "upload" ] ; then
    if [ ! -e "${UPLOAD_CONFIG}" ]; then
        echo "upload action requires upload.yaml file"
        usage
        exit 1
    fi
    if [ "${M5NR_VERSION}" == "" ]; then
        echo "upload action requires m5nr version"
        usage
        exit 1
    fi
    if [ "${TOKEN}" == "" ]; then
        echo "upload action requires mg-rast token"
        usage
        exit 1
    fi
    
    echo "Uploading Started: "`date +"%Y%m%d.%H%M"`
    echo
    echo "Data\tFile\tNode ID"
    ${UPLOADER} --type build --dir Build --token ${TOKEN} --config ${UPLOAD_CONFIG} --version ${M5NR_VERSION}
    echo
    echo "Uploading Completed: "`date +"%Y%m%d.%H%M"`
else
    echo "invalid action"
    usage
    exit 1
fi
