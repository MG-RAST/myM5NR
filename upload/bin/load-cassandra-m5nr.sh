#!/bin/bash

set -e

# set default value
MY_IP=""
ALL_IPS=""
VERSION=""
REP_NUM="3"
DATA_URL=""

DATA_DIR="/m5nr_data/Upload/cassandra"
SCHEMA_DIR="/myM5NR/schema"
LOAD_DIR="/myM5NR/BulkLoader"

CASS_BIN="/usr/bin"
CASS_DIR="/usr/share/cassandra"
CASS_CONF="/etc/cassandra/cassandra.yaml"

function usage {
  echo "Usage: $0 -i <this node IP> -a <all node IPs> -v <m5nr version> -u <data shock URL> -r <replica number> -d <data install dir> [-h <help>] "
  echo "   -h <help>  "
  echo "   -i this node IP "
  echo "   -a all node IPs, comma seperated "
  echo "   -v m5nr version "
  echo "   -u data input URL "
  echo "   -r replica number, default ${REP_NUM} "
  echo "   -d data install dir, default ${DATA_DIR} "
}

while getopts hi:a:v:u:r:d: option; do
    case "${option}"
        in
            h) HELP=1;;
            i) MY_IP=${OPTARG};;
            a) ALL_IPS=${OPTARG};;
            v) VERSION=${OPTARG};;
            u) DATA_URL=${OPTARG};;
            r) REP_NUM=${OPTARG};;
            d) DATA_DIR=${OPTARG};;
    esac
done

# check options
if [ "${HELP}" -eq 1 ]; then
    usage
    exit 0
fi

if [ -z "$VERSION" ] || [ -z "$DATA_URL" ] || [ -z "$MY_IP" ] || [ -z "$ALL_IPS" ]; then
    echo "Missing required option"
    usage
    exit 1
fi

set -x

CQLSH=$CASS_BIN/cqlsh
SST_LOAD=$CASS_BIN/sstableloader
M5NR_DATA=$DATA_DIR/src/v${VERSION}

# schema from template
SCHEMA_TABLE=$SCHEMA_DIR/m5nr_table_v${VERSION}.cql
SCHEMA_COPY=$SCHEMA_DIR/m5nr_copy_v${VERSION}.cql
sed -e "s;\[\% version \%\];$VERSION;g" -e "s;\[\% replication \%\];$REP_NUM;g" $SCHEMA_DIR/m5nr_table.cql.tt > $SCHEMA_TABLE
sed -e "s;\[\% version \%\];$VERSION;g" -e "s;\[\% data_dir \%\];$M5NR_DATA;g" $SCHEMA_DIR/m5nr_copy.cql.tt > $SCHEMA_COPY

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

set +e
echo "Copying small data ..."
sed -i "s;\(^import csv$\);\1\ncsv.field_size_limit(1000000000);" ${CQLSH}.py
$CQLSH --request-timeout 600 --connect-timeout 600 -f $SCHEMA_COPY $MY_IP
set -e

echo "Creating / loading sstables ..."
SST_DIR=$DATA_DIR/sstable
KEYSPACE=m5nr_v${VERSION}
mkdir -p $SST_DIR
for TYPE in midx md5; do
    # split large file
    cd $M5NR_DATA
    split -a 3 -d -l 2500000 m5nr.annotation.${TYPE} m5nr.annotation.${TYPE}.
    # create sstables
    cd $LOAD_DIR
    for FILE in `ls $M5NR_DATA/m5nr.annotation.${TYPE}.*`; do
        /bin/bash BulkLoader.sh -c $CASS_CONF -d $CASS_DIR -k $KEYSPACE -t ${TYPE}_annotation -i $FILE -o $SST_DIR
        rm $FILE
    done
    # load sstable
    $SST_LOAD -f $CASS_CONF -d $ALL_IPS $SST_DIR/$KEYSPACE/${TYPE}_annotation
done

exit 0