#!/bin/bash

SOURCE=$1

cd /m5nr_data
/myM5NR/bin/m5nr_compiler.py parse --debug --force --source $SOURCE

while [ $? -eq 42 ]; do
    echo "$SOURCE missing dependency, sleeping ..."
    sleep 300
    /myM5NR/bin/m5nr_compiler.py parse --debug --force --source $SOURCE
done

echo "$SOURCE parsing completed"
