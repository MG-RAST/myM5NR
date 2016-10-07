#!/bin/sh

# MASTER SCRIPT for building m5nr 

# ENV
MYM5NR=/root/m5nr
SOURCES=${MYM%NR}/Sources
PARSED=${MYM%NR}/PARSED

# echo warning to users
echo "If you are executing this in a docker container, you might want to mount the /root/m5nr directory to avoid re-downloading the data"

# download
download_m5nr_sources.sh ${SOURCES  2>&1 | tee logfile1.txt

# parse the files
source2ach.sh 8 ${SOURCES} ${PARSED}  2>&1 | tee logfile1.txt"


# (Partially merge) sort all md52seq files
for i in ${SOURCES_PROTEIN} ${SOURCES_RNA} ; 
do 
	cat ${i}/*.md52seq | sort -S 50% -u > ${i}_sorted.md52seq_part 
	&& mv ${i}_sorted.md52seq_part ${i}_sorted.md52seq ; 
done
# (warning: exclude CAZy ! it has no .md52seq file, or use empty file ?)


# Check if files exist
for i in ${SOURCES_PROTEIN} 
do 
	file ${i}_sorted.md52seq ; 
done


# Merge sorted files (sort -m does not sort!)
sort -m -u -S 50% `for i in ${SOURCES_PROTEIN} ; do echo -n "${i}_sorted.md52seq " ; done` -o all_protein.md52seq

# Create actual FASTA files
cat all_rna.md52seq | while read md5 seq ; do echo ">"$md5 ; echo $seq ; done > m5rna.fasta
cat all_protein.md52seq | while read md5 seq ; do echo ">"$md5 ; echo $seq ; done > m5nr.fasta

