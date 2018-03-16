#!/bin/bash

TODO=$1

FIRST_LIST="BacMet CARD GenBank NCBI-Taxonomy SEED-Subsystems motuDB"
SECOND_LIST="Greengenes PATRIC PhAnToMe RDP RefSeq SEED-Annotations SILVA-LSU SILVA-SSU Swiss-Prot TrEmble"
THIRD_LIST="goslim CAZy COG EC EggNOG InterPro KEGG PFAM"

PROCS=4

cd /m5nr_data

if [ "$TODO" -eq "1" ] || [ "$TODO" -eq "all" ]; then
    echo "Parsing ${FIRST_LIST}"
    echo ${FIRST_LIST} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} /myM5NR/bin/m5nr_compiler.py parse -d -f -s {}
fi

if [ "$TODO" -eq "2" ] || [ "$TODO" -eq "all" ]; then
    echo "Parsing ${SECOND_LIST}"
    echo ${SECOND_LIST} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} /myM5NR/bin/m5nr_compiler.py parse -d -f -s {}
fi

if [ "$TODO" -eq "3" ] || [ "$TODO" -eq "all" ]; then
    echo "Parsing ${THIRD_LIST}"
    echo ${THIRD_LIST} | tr ' ' '\n' | xargs -n 1 -I {} -P ${PROCS} /myM5NR/bin/m5nr_compiler.py parse -d -f -s {}
fi

echo "Parsing Completed"
