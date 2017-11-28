#!/bin/bash

#
# this is deprecated
#

echo "this is deprecated"
exit 1

# DOCUMENTATION
#
# This script will try to download all sources specified in SOURCES. For each source it will create a directory within the
# general download directory passed as an argument to this script. Individual sources are only downloaded if its
# <source> directory does not exist yet. When download starts, files are stored in a directory called <source>_part.
# Once download has finished successfully, the directory <source>_part will be renamed <source>.
# If a download fails, the download function return with an error and the script will continue downloading other sources. A
# summary at the end shows what sources were downloaded and which failed:
#
# DOWNLOADS_EXIST= sources that were already downloaded
# DOWNLOADS_GOOD=  sources that were successfully downloaded
# DOWNLOADS_BAD=   sources that failed










#developer notes:
#for testing: SOURCES="test1 test2"



if [ $# -ne 1 ]
then
	echo "USAGE: download_m5nr_sources.sh <download dir> 2>&1 | tee logfile1.txt"
	echo "<download dir> will contain the individual source download directories"
	exit 1
fi

DOWNLOAD_DIR=${1%/} # will remove trailing slash

if [ ! -d "$DOWNLOAD_DIR" ]; then
	echo "error: download directory not found"
	exit 1
fi

# binary location from http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
BIN=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ -z ${SOURCES+x} ]; then

	SOURCE_CONFIG=${BIN}/../sources.cfg

	if [ ! -e ${SOURCE_CONFIG} ]; then
		echo "source config file ${SOURCE_CONFIG} not found"
		exit 1
	fi

	source ${SOURCE_CONFIG} # this defines ${SOURCES}

fi

DOWNLOADS_EXIST=""
DOWNLOADS_GOOD=""
DOWNLOADS_BAD=""

###########################################################
# Check that our kit is ok: 
if ! wget -h  > /dev/null 2>&1
then
echo ERROR:  Command wget not found in PATH.  Install wget to continue.
DEPEND_FAIL=1
fi

if ! curl -h  > /dev/null 2>&1
then
echo ERROR:  Command curl not found in PATH.  Install curl to continue.
DEPEND_FAIL=1
fi

if ! lftp -h  > /dev/null 2>&1
then
echo ERROR:  Command lftp not found in PATH.  Install lftp to continue.
DEPEND_FAIL=1
fi

if ! perl -e 'use DB_File'  > /dev/null 2>&1
then
echo ERROR: Perl module DB_File, needed by SEED API not found.  
echo        Try  perl -MCPAN -e 'install DB_File'  to install
DEPEND_FAIL=1
fi

if ! perl -e 'use SeedEnv' > /dev/null  2>&1
then
echo ERROR: Perl SEED API distribution package not found.  Follow instructions at 
echo       http://blog.theseed.org/servers/installation/distribution-of-the-seed-server-packages.html 
echo       to install the SEED API perl package.
DEPEND_FAIL=1
fi

if [[ "$DEPEND_FAIL" == "1" ]]
then
echo Aborting, some dependencies not met.
exit 1
fi


###########################################################
# download functions

# ${1} is the "..._part" download directory, specific to individual source


set -x

#### proteins

function download_CAZy_deprecated {
	${BIN}/get_cazy_table.pl ${1}/cazy_all_v042314.txt || return $?
}


function download_eggNOGs_deprecated {
	# version 4 available, but different format, thus we use old version for now.
	echo "Using v3 not v4 yet"

	########## v4.0 (COG stuff seems to be missing, UniProtAC2eggNOG changed)
	# former fun.txt.gz
	#ftp://eggnog.embl.de/eggNOG/4.0/eggnogv4.funccats.txt

	### UniProtAC2eggNOG contains content that was provided by UniProtAC2eggNOG.3.0.tsv.gz, but different format!
	#ftp://eggnog.embl.de/eggNOG/4.0/id_conversion.tsv

	### funcat
	# COG.funccat.txt.gz missing !? use old v3 ?
	#ftp://eggnog.embl.de/eggNOG/4.0/funccat/NOG.funccat.txt.gz

	### description
	# COG.description.txt.gz is missing
	#ftp://eggnog.embl.de/eggNOG/4.0/description/NOG.description.txt.gz

	### sequence
	# ftp://eggnog.embl.de/eggNOG/4.0/eggnogv4.proteins.all.fa.gz


	# v3.0

  for file in fun.txt.gz UniProtAC2eggNOG.3.0.tsv.gz COG.funccat.txt.gz NOG.funccat.txt.gz COG.description.txt.gz NOG.description.txt.gz sequences.v3.tar.gz ; do
    wget http://eggnogdb.embl.de/download/eggnog_3.0/${file} || return $?
  done
  echo "3.0" > version.txt

}

function download_COGs_depreacted {
	time lftp -c "open -e 'mirror -v --no-recursion /pub/COG/COG2014/data/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}

function download_FungiDB_depreacted {
	# use old version, does not seem to be updated anymore
	echo "Please use archived version for FungiDB."
	return 1
	#wget -v -N -P ${1} 'http://fungalgenomes.org/public/mobedac/for_VAMPS/fungalITSdatabaseID.taxonomy.seqs.gz' || return $?
}

function download_IMG_depreacted {
	echo "Please use archived version for IMG."
	#echo "ftp path is missing (copy archived version)"
	#time lftp -c "open -e 'mirror -v --no-recursion -I img_core_v400.tar /pub/IMG/ ${1}' ftp://ftp.jgi-psf.org"
	return 1
}

function download_InterPro_deprecated {

	DIR="${1}/"
	export VERSION_REMOTE=`curl --silent ftp://ftp.ebi.ac.uk/pub/databases/interpro/current/release_notes.txt | grep "Release [0-9]" | grep -o "[0-9]*\.[0-9]*"`
	echo "remote version: ${VERSION_REMOTE}"
	if [ "${VERSION_REMOTE}_" == "_" ] ; then
		echo "VERSION_REMOTE missing"
		return 1
	fi

	wget -P ${DIR} --recursive --no-clobber --convert-links --no-parent ftp://ftp.ebi.ac.uk/pub/databases/interpro/${VERSION_REMOTE} || return $?

	mv ${DIR}ftp.ebi.ac.uk/pub/databases/interpro/${VERSION_REMOTE}/* .
	rm -rf ${DIR}ftp.ebi.ac.uk

	# write version
	cat ${DIR}release_notes.txt | grep "Release [0-9]" | grep -o "[0-9]*\.[0-9]*" > ${DIR}version.txt
}

function download_KEGG_deprecated {
	echo KEGG is no longer available.
	return 1
	#time lftp -c "open -e 'mirror -v --no-recursion -I genome /pub/kegg/genes/ ${1}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I genes.tar.gz /pub/kegg/release/current/ ${1}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I ko /pub/kegg/genes/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --parallel=2 -I *.keg /pub/kegg/brite/ko/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
}

function download_MO_deprecated {
	# we are not using this MG right now.
	# issue with recursive wget and links on page, this hack works
	for i in `seq 1 907348`; do wget -N -P ${1} http://www.microbesonline.org/genbank/${i}.gbk.gz 2> /dev/null; done
	wget -v -N -P ${1} http://www.microbesonline.org/genbank/10000550.gbk.gz
}

function download_GenBankNR_deprecated {
	time lftp -c "open -e 'mirror -v -e --no-recursion -I nr.gz /blast/db/FASTA/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
	stat -c '%y' ${1}/nr.gz | cut -c 1-4,6,7,9,10 > ${1}/version.txt
}

function download_PATRIC_deprecated {
	time lftp -c "open -e 'mirror -v --parallel=2 -I *.PATRIC.gbf /patric2/genomes/ ${1}' http://brcdownloads.vbi.vt.edu" || return $?
	# use one of the directories time stamp
	stat -c '%y' ${1}/1000561.3 | cut -c 1-4,6,7,9,10 > ${1}/version.txt
}


function version_Phantome_deprecated {
	export TIMESTAMP=`curl --silent http://www.phantome.org/Downloads/proteins/all_sequences/ | grep -o phage_proteins_[0-9]*.fasta.gz | sort | tail -n 1 | grep -o "[0-9]*"` || return $?
	export VERSION=`date -d @${TIMESTAMP} +"%Y%m%d"`
}

function download_Phantome_deprecated {
	
	version_Phantome

	echo "$VERSION" > ${1}/version.txt

	# 20150403 is in shock

	#find node
	#curl "http://shock.metagenomics.anl.gov/node?query&type=data-library&project=M5NR&data-library-name=M5NR_source_Phantome"
	SOURCE=`basename ${1}`
	OLD_NODE=`curl --silent "http://shock.metagenomics.anl.gov/node?query&type=data-library&project=M5NR&data-library-name=M5NR_source_${SOURCE}&version=${VERSION}" | grep -o "[0-f]\{8\}-[0-f]\{4\}-[0-f]\{4\}-[0-f]\{4\}-[0-f]\{12\}"` || return $?
	
	if [ "${OLD_NODE}_" != "_" ] ; then
		#download from shock?
		echo "found shock node"
		return
        else
                echo "Phantome ${VERSION} not found in shock"
	fi
	
	wget -v -N -P ${1} "http://www.phantome.org/Downloads/proteins/all_sequences/phage_proteins_${TIMESTAMP}.fasta.gz"  || return $?
	
	
}

function download_RefSeq_deprecated {
	time lftp -c "open -e 'mirror -v -e --delete-first -I RELEASE_NUMBER /refseq/release/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I *.genomic.gbff.gz /refseq/release/complete/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
	cp ${1}/RELEASE_NUMBER ${1}/version.txt
}



function download_SEED_deprecated {

	CURRENT_VERSION=$(echo `date +"%Y%m%d"`) 
	time ${BIN}/querySAS.pl --source=SEED  --output=${1}/SEED.md52id2func2org || return $?
	echo ${CURRENT_VERSION} > ${1}/version.txt
	#old:
	#time lftp -c "open -e 'mirror -v --no-recursion -I SEED.fasta /misc/Data/idmapping/ ${1}' ftp://ftp.theseed.org"
	#time lftp -c "open -e 'mirror -v --no-recursion -I subsystems2role.gz /subsystems/ ${1}' ftp://ftp.theseed.org"
}


function download_Subsystems_deprecated {  
	time ${BIN}/querySAS.pl --source=Subsystems --output=${1}/Subsystems.subsystem2role2seq || return $?
}

function download_UniProt_deprecated {
	time lftp -c "open -e 'mirror -v -e --delete-first -I reldate.txt  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_sprot.dat.gz  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_trembl.dat.gz /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	head -n1 ${1}/reldate.txt | grep -o "[0-9]\{4\}_[0-9]*" > ${1}/version.txt
}


#### RNA

function download_SILVA_deprecated {
	time lftp -c "open -e 'mirror -v --no-recursion --dereference /current/Exports/ ${1}' ftp://ftp.arb-silva.de" || return $?
	mkdir -p ${1}/rast
	time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/rast ${1}/rast' ftp://ftp.arb-silva.de" || return $?
	head -n1 ${1}/README.txt  | grep -o "SILVA [0-9.]*" | cut -d ' ' -f 2 > ${1}/version.txt
}

function download_RDP_deprecated {

	# version number
	curl --silent 'http://rdp.cme.msu.edu/download/releaseREADME.txt' > version.txt || return $?

	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/releaseREADME.txt' || return $?
			
}

function download_Greengenes_deprecated {
	# from 2011 ?

	curl --silent http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/ | grep current_GREENGENES_gg16S_unaligned.fasta.gz | grep -o "[0-9][0-9]-.*-[0-9][0-9][0-9][0-9]" > version.txt || return $?
	wget -v -N -P ${1} 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz' || return $?
	# use filedata as version
	#stat -c '%y' current_GREENGENES_gg16S_unaligned.fasta.gz | cut -c 1-4,6,7,9,10 > ${1}/version.txt
}

set +x

###########################################################

for i in ${SOURCES}
do
	echo "check $i"
	SOURCE_DIR="${DOWNLOAD_DIR}/${i}"
	SOURCE_DIR_PART="${DOWNLOAD_DIR}/${i}_part"
	if [ ! -d "${SOURCE_DIR}" ]; then
		echo "${SOURCE_DIR} not found. Downloading..." `date`
		if [ -d "${SOURCE_DIR_PART}" ]; then
			echo "${SOURCE_DIR_PART} download already exists. Please delete manually"
			exit
		fi
		mkdir -m 775 ${SOURCE_DIR_PART}

		echo "Downloading ${i} to ${SOURCE_DIR_PART}"
    pushd ${SOURCE_DIR_PART}
		set -x
		# this is the function call. It will (should) stop the script if download fails.
		download_${i} ${SOURCE_DIR_PART}
		DOWNLOAD_RESULT=$?
    popd
		echo `date +"%Y%m%d"` > ${SOURCE_DIR_PART}/timestamp.txt
		set +x
		if [ ${DOWNLOAD_RESULT} -ne 0 ] ; then
			echo "downloading ${i} failed with exit code ${DOWNLOAD_RESULT}"
			DOWNLOADS_BAD="${DOWNLOADS_BAD} ${i}"
		else
			echo "downloading ${i} was succesful"
			DOWNLOADS_GOOD="${DOWNLOADS_GOOD} ${i}"
			# this confirms download was successful
			echo "mv ${SOURCE_DIR_PART} ${SOURCE_DIR}"
			mv ${SOURCE_DIR_PART} ${SOURCE_DIR}
		fi
		echo "State of downloads:"
		echo "DOWNLOADS_EXIST=${DOWNLOADS_EXIST}"
		echo "DOWNLOADS_GOOD=${DOWNLOADS_GOOD}"
		echo "DOWNLOADS_BAD=${DOWNLOADS_BAD}"
	else
		DOWNLOADS_EXIST="${DOWNLOADS_EXIST} ${i}"
	fi

done

echo Done `date`



