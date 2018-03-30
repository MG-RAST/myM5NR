#!/bin/bash

# set option
HELP=0
ACTION=''
PROCS=4
SOURCE_CONFIG=''
BUILD_CONFIG=''
M5NR_VERSION=''
COMPILER='/myM5NR/bin/m5nr_compiler.py'

function usage {
  echo "Usage:   $0 -a <action> -p <procs> -s <source config> -b <build config> -c <m5nr_compiler.py> -v <m5nr version> [-h <help>] "
  echo "   -h <help>  "
  echo "   -a (download|parse|build) "
  echo "   -p <# of threads to use> "
  echo "   -s sources.yaml file "
  echo "   -b build.yaml file "
  echo "   -c /path/to/m5nr_compiler.py "
  echo "   -v m5nr version "
}

# get options
while getopts ha:p:s:b:v: option; do
    case "${option}"
	in
	    h) HELP=1;;
	    a) ACTION=${OPTARG};;
	    p) PROCS=${OPTARG};;
	    s) SOURCE_CONFIG=${OPTARG};;
	    b) BUILD_CONFIG=${OPTARG};;
        v) M5NR_VERSION=${OPTARG};;
    esac
done

# check options
if   [ "${HELP}" -eq 1 ] || [ -z "${ACTION}" ]; then
    usage
    exit 1
fi

# run actions
if [ "${ACTION}" == "download" ] || [ "${ACTION}" == "parse" ]; then
    if [ ! -e "${SOURCE_CONFIG}" ]; then
        echo "download / parse actions requires sources.yaml file"
        usage
        exit 1
    fi
    
    SOURCES=`grep '^[A-Za-z]' ${SOURCE_CONFIG} | cut -f1 -d':'`
    
    if [ "${ACTION}" == "download" ]; then
        mkdir -p Sources
        echo "Downloading Started: "`date +"%Y%m%d.%H%M"`
        echo ${SOURCES} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} ${COMPILER} download -f -d -s {}
        echo "Downloading Completed: "`date +"%Y%m%d.%H%M"`
    elif [ "${ACTION}" == "parse" ]; then
        mkdir -p Parsed
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
    
    mkdir -p Build
    
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
else
    echo "invalid action"
    usage
    exit 1
fi
