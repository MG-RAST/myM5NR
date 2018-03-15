#!/bin/bash

GENOME_URL='https://p3.theseed.org/services/data_api/genome'
FEATURE_URL='https://p3.theseed.org/services/data_api/genome_feature'

# all between CDS count 0 - 10000, per range of 100
for MIN in `seq 0 100 9900`; do
    MAX=$((MIN + 100))
    GENOMES=`curl -s ${GENOME_URL} --data "eq(taxon_lineage_ids,131567)&select(genome_id)&limit(25000)&ge(patric_cds,${MIN})&lt(patric_cds,${MAX})" 2> /dev/null | tail -n +2 | tr -d '"'`
    for GID in `echo ${GENOMES}`; do
        FILE="${GID}.features.json"
        if [ ! -e ${FILE} ] ; then
            rm -f ${FILE}_part
            curl -s -o ${FILE}_part ${FEATURE_URL} -H 'Accept: application/solr+json' --data "in(genome_id,(${GID}))&limit(25000)&facet((field,feature_type),(mincount,1))" 2> /dev/null
            mv ${FILE}_part ${FILE}
        fi
    done
done

# all with CDS count > 10000
GENOMES=`curl -s ${GENOME_URL} --data "eq(taxon_lineage_ids,131567)&select(genome_id)&limit(25000)&ge(patric_cds,10000)" 2> /dev/null | tail -n +2 | tr -d '"'`
for GID in `echo ${GENOMES}`; do
    FILE="${GID}.features.json"
    if [ ! -e ${FILE} ] ; then
        rm -f ${FILE}_part
        curl -s -o ${FILE}_part ${FEATURE_URL} -H 'Accept: application/solr+json' --data "in(genome_id,(${GID}))&limit(25000)&facet((field,feature_type),(mincount,1))" 2> /dev/null
        mv ${FILE}_part ${FILE}
    fi
done
