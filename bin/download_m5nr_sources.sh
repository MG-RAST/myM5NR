#!/bin/bash

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
	echo "USAGE: download_ach_sources.sh <download dir> 2>&1 | tee logfile1.txt"
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


SOURCE_CONFIG=${BIN}/../sources.cfg

if [ ! -e ${SOURCE_CONFIG} ]; then
	echo "source config file ${SOURCE_CONFIG} not found"
	exit 1
fi

source ${SOURCE_CONFIG} # this defines ${SOURCES}


DOWNLOADS_EXIST=""
DOWNLOADS_GOOD=""
DOWNLOADS_BAD=""


###########################################################
# download functions

# ${1} is the "..._part" download directory, specific to individual source


set -x

#### proteins

function download_CAZy {
	${BIN}/get_cazy_table.pl ${1}/cazy_all_v042314.txt || return $?
	echo `date +"%Y%m%d"` > ${1}/timestamp.txt
}


function download_eggNOG {
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
	time lftp -c "open -e 'mirror -v -e --no-recursion \\
		-I fun.txt.gz \\
		-I UniProtAC2eggNOG.3.0.tsv.gz \\
		-I COG.funccat.txt.gz \\
		-I NOG.funccat.txt.gz \\
		-I COG.description.txt.gz \\
		-I NOG.description.txt.gz \\
		-I sequences.v3.tar.gz \\
		/eggNOG/3.0/ ${1}' ftp://eggnog.embl.de" || return $?


}

function download_COGs {
	time lftp -c "open -e 'mirror -v --no-recursion /pub/COG/COG2014/data/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}

function download_FungiDB {
	# use old version, does not seem to be updated anymore
	echo "Please use archived version for FungiDB."
	return 1
	#wget -v -N -P ${1} 'http://fungalgenomes.org/public/mobedac/for_VAMPS/fungalITSdatabaseID.taxonomy.seqs.gz' || return $?
}

function download_IMG {
	echo "Please use archived version for IMG."
	#echo "ftp path is missing (copy archived version)"
	#time lftp -c "open -e 'mirror -v --no-recursion -I img_core_v400.tar /pub/IMG/ ${1}' ftp://ftp.jgi-psf.org"
	return 1
}

function download_InterPro {
	# see release_notes.txt for version
	time lftp -c "open -e 'mirror -v --no-recursion /pub/databases/interpro/Current/ ${1}' ftp://ftp.ebi.ac.uk" || return $?
}

function download_KEGG {
	echo KEGG is no longer available.
	return 1
	#time lftp -c "open -e 'mirror -v --no-recursion -I genome /pub/kegg/genes/ ${1}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I genes.tar.gz /pub/kegg/release/current/ ${1}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I ko /pub/kegg/genes/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --parallel=2 -I *.keg /pub/kegg/brite/ko/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
}

function download_MO {
	# we are not using this MG right now.
	# issue with recursive wget and links on page, this hack works
	for i in `seq 1 907348`; do wget -N -P ${1} http://www.microbesonline.org/genbank/${i}.gbk.gz 2> /dev/null; done
	wget -v -N -P ${1} http://www.microbesonline.org/genbank/10000550.gbk.gz
}

function download_GenBankNR {
	time lftp -c "open -e 'mirror -v -e --no-recursion -I nr.gz /blast/db/FASTA/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}

function download_PATRIC {
	time lftp -c "open -e 'mirror -v --parallel=2 -I *.PATRIC.gbf /patric2/genomes/ ${1}' http://brcdownloads.vbi.vt.edu" || return $?
}

function download_Phantome {
	wget -v -O ${1}/phage_proteins.fasta.gz 'http://www.phantome.org/Downloads/proteins/all_sequences/current'  || return $?
}

function download_RefSeq {
	time lftp -c "open -e 'mirror -v -e --delete-first -I RELEASE_NUMBER /refseq/release/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I *.genomic.gbff.gz /refseq/release/complete/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}



function download_SEED {

	# TODO use current
	#CURRENT="ProblemSets.current"
	CURRENT="ProblemSets.2015.01"

	time ${BIN}/querySAS.pl -source SEED  1> ${1}/SEED.md52id2func2org || return $?
	time lftp -c "open -e 'mirror -v /SeedProjectionRepository/Releases/${CURRENT}/ ${1}' ftp://ftp.theseed.org" || return $?

	#old:
	#time lftp -c "open -e 'mirror -v --no-recursion -I SEED.fasta /misc/Data/idmapping/ ${1}' ftp://ftp.theseed.org"
	#time lftp -c "open -e 'mirror -v --no-recursion -I subsystems2role.gz /subsystems/ ${1}' ftp://ftp.theseed.org"
}


function download_Subsystems {
	time ${BIN}/querySAS.pl -source Subsystems  1> ${1}/Subsystems.subsystem2role2seq || return $?
}

function download_UniProt {
	time lftp -c "open -e 'mirror -v -e --delete-first -I reldate.txt  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_sprot.dat.gz  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_trembl.dat.gz /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
}


#### RNA

function download_SILVA {
	time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/ ${1}' ftp://ftp.arb-silva.de" || return $?
	mdir -p ${1}/rast
	time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/rast ${1}/rast' ftp://ftp.arb-silva.de" || return $?
}

function download_RDP {

	# version number
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/releaseREADME.txt' || return $?

	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz' || return $?
}

function download_Greengenes {
	# from 2011 ?
	wget -v -N -P ${1} 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz' || return $?
	echo `date +"%Y%m%d"` > ${1}/timestamp.txt
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

		set -x
		# this is the function call. It will (should) stop the script if download fails.
		download_${i} ${SOURCE_DIR_PART}
		DOWNLOAD_RESULT=$?
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



