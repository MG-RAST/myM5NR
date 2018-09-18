#!/bin/bash

set -e

# set default value
MY_IP=""
ALL_IPS=""
VERSION="1"
REP_NUM="4"
DATA_DIR="/var/lib/cassandra"
DATA_URL=""

CASS_BIN="/usr/bin"
CASS_DIR="/usr/share/cassandra"
CASS_CONF="/etc/cassandra/cassandra.yaml"
LOAD_URL="https://raw.githubusercontent.com/MG-RAST/MG-RAST-infrastructure/master/services/cassandra-load"

function usage {
  echo "Usage: $0 -i <this node IP> -a <all node IPs> -v <m5nr version> -r <replica number> -d <data install dir> -u <data shock URL> [-h <help>] "
  echo "   -h <help>  "
  echo "   -i this node IP "
  echo "   -a all node IPs, comma seperated "
  echo "   -v m5nr version, default use Version 1 "
  echo "   -r replica number, default ${REP_NUM} "
  echo "   -d data install dir, default ${DATA_DIR} "
  echo "   -u data shock URL, default use Version 1 "
}

while getopts i:a:v:r:d: option; do
    case "${option}"
        in
            i) MY_IP=${OPTARG};;
            a) ALL_IPS=${OPTARG};;
            v) VERSION=${OPTARG};;
            r) REP_NUM=${OPTARG};;
            d) DATA_DIR=${OPTARG};;
    esac
done

# check options
if [ "${HELP}" -eq 1 ]; then
    usage
    exit 0
fi

if [ -z "$MY_IP" ] || [ -z "$ALL_IPS" ]; then
    echo "Missing IPs"
    usage
    exit 1
fi

set -x

LOAD_DIR=$DATA_DIR/BulkLoader
SCHEMA_DIR=$DATA_DIR/schema
M5NR_DATA=$DATA_DIR/src/v${VERSION}
SCHEMA_TABLE=$SCHEMA_DIR/m5nr_table_v${VERSION}.cql
SCHEMA_COPY=$SCHEMA_DIR/m5nr_copy_v${VERSION}.cql

CQLSH=$CASS_BIN/cqlsh
SST_LOAD=$CASS_BIN/sstableloader

# download schema template
mkdir -p $SCHEMA_DIR
cd $SCHEMA_DIR
curl -s $LOAD_URL/m5nr/m5nr_table.cql.tt | \
    sed -e "s;\[\% version \%\];$VERSION;g" -e "s;\[\% replication \%\];$REP_NUM;g" > $SCHEMA_TABLE
curl -s $LOAD_URL/m5nr/m5nr_copy.cql.tt | \
    sed -e "s;\[\% version \%\];$VERSION;g" -e "s;\[\% data_dir \%\];$M5NR_DATA;g" > $SCHEMA_COPY

# download bulkloader
mkdir -p $LOAD_DIR
cd $LOAD_DIR
curl -s -O $LOAD_URL/BulkLoader/BulkLoader.sh
curl -s -O $LOAD_URL/BulkLoader/BulkLoader.java
curl -s -O $LOAD_URL/BulkLoader/opencsv-3.4.jar

# download data
if [ "$VERSION" == "1" ]; then
    DATA_URL="http://shock.metagenomics.anl.gov/node/4ce1ec2f-58f1-48fa-86cd-3bff227db165?download"
fi
if [ "$DATA_URL" == "" ]; then
    echo "Data URL required for version > 1"
    usage
    exit 1
fi

echo ""
echo "REPLICATES = $REP_NUM"
echo "M5NR_VERSION = $VERSION"
echo "M5NR_DATA = $M5NR_DATA"
echo "DATA_URL = $DATA_URL"
echo ""

if [ ! -d $M5NR_DATA ]; then
    mkdir -p $M5NR_DATA
    echo "Downloading and unpacking data ..."
    curl -s "${DATA_URL}" | tar -zxvf - -C $M5NR_DATA
fi

# fix organism table
#sed -i 's\""$\"0"\' ${M5NR_DATA}/m5nr_v${VERSION}.taxonomy.all

# load tables
echo "Loading schema ..."
$CQLSH --request-timeout 600 --connect-timeout 600 -f $SCHEMA_TABLE $MY_IP

echo "Copying small data ..."
sed -i "s;\(^import csv$\);\1\ncsv.field_size_limit(1000000000);" ${CQLSH}.py
$CQLSH --request-timeout 600 --connect-timeout 600 -f $SCHEMA_COPY $MY_IP

echo "Creating / loading sstables ..."
SST_DIR=$DATA_DIR/sstable
KEYSPACE=m5nr_v${VERSION}
mkdir -p $SST_DIR
for TYPE in midx md5; do
    # split large file
    cd $M5NR_DATA
    split -a 2 -d -l 2500000 ${KEYSPACE}.annotation.${TYPE} ${KEYSPACE}.annotation.${TYPE}.
    # create sstables
    cd $LOAD_DIR
    for FILE in `ls $M5NR_DATA/${KEYSPACE}.annotation.${TYPE}.*`; do
        /bin/bash BulkLoader.sh -c $CASS_CONF -d $CASS_DIR -k $KEYSPACE -t ${TYPE}_annotation -i $FILE -o $SST_DIR
        rm $FILE
    done
    # load sstable
    $SST_LOAD -f $CASS_CONF -d $ALL_IPS $SST_DIR/$KEYSPACE/${TYPE}_annotation
done

exit 0