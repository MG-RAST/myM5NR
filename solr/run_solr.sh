#!/bin/sh -e

# this script runs solr in foreground

# max Java memory is 80% of system memory

set -e
set -x

NAME="solr"
PIDFILE="/var/run/${NAME}.pid"
SOLR_DIR="/kb/runtime/solr/example"
TOT_MEM=`free -m | awk '/Mem:/ { print $2 }'`
JAVA_MEM=`echo "${TOT_MEM} * 0.8" | bc | cut -f1 -d"."`
JAVA_OPTIONS="-Xms1024M -Xmx${JAVA_MEM}M -DSTOP.PORT=8079 -DSTOP.KEY=stopkey -jar start.jar"
JAVA=`which java`


echo -n "Starting $NAME... "
if [ -f $PIDFILE ]; then
	echo "is already running!"
else
	cd $SOLR_DIR
	$JAVA $JAVA_OPTIONS
	echo "(Done)"
fi

