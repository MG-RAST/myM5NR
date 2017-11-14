#!/bin/bash

for file in $(curl --silent ftp://ftp.patricbrc.org/patric2/current_release/gbf/ | head | grep -o "[0-9\.]*.PATRIC.gbf" ) ; do
  if [ ! -e ${file} ] ; then
    rm -f ${file}_part
    curl --silent -o ${file}_part ftp://ftp.patricbrc.org/patric2/current_release/gbf/${file} && mv ${file}_part ${file}
  fi 
done