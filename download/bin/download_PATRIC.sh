#!/bin/bash

GENOME_URL='https://p3.theseed.org/services/data_api/genome'
FEATURE_URL='https://p3.theseed.org/services/data_api/genome_feature'

SELF=$0
ACTION=$1
VALUE=$2

# here we just download one genome file
if [ "$ACTION" == "download" ]; then
    
    PREFIX=`echo ${VALUE} | cut -f1 -d'.'`
    SIZE=${#PREFIX}
    SUBDIR=""
    if [ "$SIZE" -le "2" ]; then
        SUBDIR=$PREFIX
    else
        SUBDIR=${PREFIX:0:2}
    fi
    mkdir -p ${SUBDIR}
    
    FILE="${SUBDIR}/${VALUE}.features.json"
    FSIZE=0
    if [ -e ${FILE} ]; then
        FSIZE=$(stat -c%s ${FILE})
    fi
    
    if [ "${FSIZE}" -lt "10" ]; then
        rm -f ${FILE} ${FILE}_part
        curl -s -o ${FILE}_part ${FEATURE_URL} -H 'Accept: application/solr+json' --data "eq(genome_id,${VALUE})&select(feature_type,aa_sequence,patric_id,product,taxon_id)&limit(25000)&facet((field,feature_type),(mincount,1))" 2> /dev/null
        mv ${FILE}_part ${FILE}
    fi
    
elif [ "$ACTION" == "wrapper" ]; then
    
    # all between CDS count 0 - 10000, per range of 100
    for MIN in `seq 0 100 9900`; do
        MAX=$((MIN + 100))
        GENOMES=`curl -s ${GENOME_URL} --data "eq(taxon_lineage_ids,131567)&select(genome_id)&limit(25000)&ge(patric_cds,${MIN})&lt(patric_cds,${MAX})" 2> /dev/null | tail -n +2 | tr -d '"'`
        COUNT=`echo ${GENOMES} | tr ' ' '\n' | wc -l`
        stdbuf -o0 echo "Downloading ${COUNT} genome files, feature count range: ${MIN} - ${MAX}"
        echo ${GENOMES} | tr ' ' '\n' | xargs -n 1 -I {} -P ${VALUE} ${SELF} download {}
    done

    # all with CDS count > 10000
    GENOMES=`curl -s ${GENOME_URL} --data "eq(taxon_lineage_ids,131567)&select(genome_id)&limit(25000)&ge(patric_cds,10000)" 2> /dev/null | tail -n +2 | tr -d '"'`
    COUNT=`echo ${GENOMES} | tr ' ' '\n' | wc -l`
    stdbuf -o0 echo "Downloading ${COUNT} genome files, feature counts > 10000"
    echo ${GENOMES} | tr ' ' '\n' | xargs -n 1 -I {} -P ${VALUE} ${SELF} download {}

else
    echo "[error] invalid action request"
    exit 1
fi
