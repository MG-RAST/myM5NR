#!/bin/bash

# A simple shell script to download the source databases for M5NR and M5RNA

# Note: This is invoked by a master script, so if download a specific database fails we need to continue and the master script needs to use the old version that was 
# successfully integrated

# this is meant to be run in data/`date +%e_%m_%Y`

# time stamp
DATE=$(date +%e_%m_%Y)

# greengenes
wget --mirror http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz
zcat greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz > ${DATE}_GREENGENES_gg16S_unaligned.fasta

# RDP
wget --mirror'http://rdp.cme.msu.edu/download/releaseREADME.txt' 
VERSION=$(cat releaseREADME.txt)
mkdir RDP-${VERSION}
rm releaseREADME.txt
cd RDP-${VERSION}
wget --mirror 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz' 
wget --mirror 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz'
wget --mirror  'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz' 
cd ..


# cog 2014
wget --mirror ftp://ftp.ncbi.nih.gov:/pub/COG/COG2014/data/

# NCBI genbank
wget --mirror ftp://ftp.ncbi.nih.gov:/blast/db/FASTA/nr.gz
ln -s ftp.ncbi.nih.gov:/blast/db/FASTA/nr.gz NCBI_nr_${DATE}.gz


# v1.1.8 The Comprehensive Antibiotic Resistance Database
wget --mirror https://card.mcmaster.ca/download/0/broadstreet-v1.1.8.tar.gz
tar xvf card.mcmaster.ca/download/0/broadstreet-v1.1.8.tar.gz

# 2014 v1.1 resistance genes
wget --mirror http://bacmet.biomedicine.gu.se/download/BacMet_PRE.40556.fasta
ln -s bacmet.biomedicine.gu.se/download/BacMet_PRE.40556.fasta BacMet_PRE.40556.fasta

# aclame
wget -O ${DATE}_aclame.gz "http://aclame.ulb.ac.be/perl/Aclame/Tools/exporter.cgi?id=all&source=proteins&entry_id=1&length=on&ncbi_desc=on&family=on&xrefs=on&sequence=on&format=gzip&x=99&y=17&notify=1"
if [ ${DATA}_aclame -ot ${DATE}_aclame.gz ]
then 
	gunzip -f ${DATE}_aclame.gz
fi


# phantome latest release
wget --mirror http://www.phantome.org/Downloads/proteins/all_sequences/current
NAME=$(file current | cut -d\" -f2 )
FILE=www.phantome.org/Downloads/proteins/all_sequences/current
if [ -f "${NAME}" ]  || [  "${NAME}" -ot "${FILE}" ]   
then
	cat ${FILE} | gunzip -- -  > ${NAME}
fi

exit

# SEED 
CURRENT_VERSION=`curl ftp://ftp.theseed.org//SeedProjectionRepository/Releases/ | grep "\.current" | grep -o "[0-9]\{4\}\.[0-9]*"`

${BIN}/querySAS.pl -source SEED  > SEED.md52id2func2org 
wget --mirror ftp://ftp.theseed.org:/SeedProjectionRepository/Releases/ProblemSets.${CURRENT_VERSION}


# SEED subsystems
${BIN}/querySAS.pl --source=Subsystems --output=Subsystems.subsystem2role2seq 

# uniprot
RefSeq_VERSION=$(curl "ftp.uniprot.org:/pub/databases/uniprot/current_release/knowledgebase/complete/reldate.txt" | head -n1 | grep -o "[0-9]\{4\}_[0-9]*")
mkdir RefSeq-${RefSeq_VERSION}
wget --mirror "ftp.uniprot.org:/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz"
wget --mirror "ftp.uniprot.org:/pub/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.dat.gz"
cd ..


# SILVA
wget --mirror  ftp://ftp.arb-silva.de:/current/Exports/rast
# might be missing additional files...

exit
# 
# eggNOG v3
wget --mirror     ftp://eggnog.embl.de/eggNOG/3.0
