#!/bin/sh

# DOCUMENTATION
#
# This script will download from a source if the <source> directory does not exist yet. When download starts, files are stored in
# a directory called <source>_part. Once download has finished successfully, the directory <source>_part will be renamed <source>.
# If a download fails, the download function return with an error and the script will continue downloading other sources. A
# summary at the end shows what sources were downloaded and which failed:
#
# DOWNLOADS_EXIST= sources that were already downloaded
# DOWNLOADS_GOOD=  sources that were successfully downloaded
# DOWNLOADS_BAD=   sources that failed


SOURCES="InterPro UniProt RefSeq SILVA FungiDB Greengenes GenbankNR PATRIC RDP COGs"
#"Phantome(is down?) SEED? "


#sources where we use archived version:
STATIC="Cazy KEGG IMG FungiDB eggNOG"



#developer notes:
#for testing: SOURCES="test1 test2"



if [ $# -ne 1 ]
then
	echo "USAGE: download_ach_sources.sh <download dir>"
	exit 1
fi

DOWNLOAD_DIR=${1%/} # will remove trailing slash

if [ ! -d "$DOWNLOAD_DIR" ]; then
	echo "error: download directory not found"
	exit 1
fi


DOWNLOADS_EXIST=""
DOWNLOADS_GOOD=""
DOWNLOADS_BAD=""


###########################################################
# download functions

# ${1} is download directory, specific to individual source
set -x

function download_test1 {
	# this one is for testing
	time wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/releaseREADME.txt' || return $? # should work
}

function download_test2 {
	# this one is for testing
	time wget -v -N -P ${1} 'http://google.com/test.txt' || return $? # will fail
}


function download_COGs {
	# not sure if this the data we need
	time lftp -c "open -e 'mirror -v --no-recursion /pub/COG/COG2014/data/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}

function download_eggNOG {
	# version 4 available, but different format, thus we use old version for now.
	echo "not updated to v4 yet"
	exit 1
	wget -v -N -P ${1} 'http://eggnog.embl.de/version_3.0/data/downloads/fun.txt.gz' || return $?
	wget -v -N -P ${1} 'http://eggnog.embl.de/version_3.0/data/downloads/UniProtAC2eggNOG.3.0.tsv.gz' || return $?
	wget -v -N -P ${1} 'http://eggnog.embl.de/version_3.0/data/downloads/COG.funccat.txt.gz' || return $?
	wget -v -N -P ${1} 'http://eggnog.embl.de/version_3.0/data/downloads/NOG.funccat.txt.gz' || return $?
	wget -v -N -P ${1} 'http://eggnog.embl.de/version_3.0/data/downloads/COG.description.txt.gz' || return $?
	wget -v -N -P ${1} 'http://eggnog.embl.de/version_3.0/data/downloads/NOG.description.txt.gz' || return $?
}

function download_FungiDB {
	# does not seem to be updated anymore
	wget -v -N -P ${1} 'http://fungalgenomes.org/public/mobedac/for_VAMPS/fungalITSdatabaseID.taxonomy.seqs.gz' || return $?
}

function download_Greengenes {
	# from 2011 ?
	wget -v -N -P ${1} 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz' || return $?
}


function download_IMG {
	echo ftp path is missing
	#time lftp -c "open -e 'mirror -v --no-recursion -I img_core_v400.tar /pub/IMG/ ${1}' ftp://ftp.jgi-psf.org"
	exit 1
}

function download_InterPro {
	# see release_notes.txt for version
	time lftp -c "open -e 'mirror -v --no-recursion /pub/databases/interpro/Current/ ${1}' ftp://ftp.ebi.ac.uk" || return $?
}

function download_KEGG {
	echo ftp is no longer accessable
	exit 1
	#time lftp -c "open -e 'mirror -v --no-recursion -I genome /pub/kegg/genes/ ${1}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I genes.tar.gz /pub/kegg/release/current/ ${1}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I ko /pub/kegg/genes/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --parallel=2 -I *.keg /pub/kegg/brite/ko/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
}

function download_MO {
	# issue with recursive wget and links on page, this hack works
	echo not using for now
	exit 1
	for i in `seq 1 907348`; do wget -N -P ${1} http://www.microbesonline.org/genbank/${i}.gbk.gz 2> /dev/null; done
	wget -v -N -P ${1} http://www.microbesonline.org/genbank/10000550.gbk.gz
}

function download_GenbankNR {
	time lftp -c "open -e 'mirror -v -e --no-recursion -I nr.gz /blast/db/FASTA/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}

function download_PATRIC {
	time lftp -c "open -e 'mirror -v --parallel=2 -I *.PATRIC.gbf /patric2/genomes/ ${1}' http://brcdownloads.vbi.vt.edu" || return $?
}

function download_Phantome {
	wget -v -O ${1}/phage_proteins.fasta.gz 'http://www.phantome.org/Downloads/proteins/all_sequences/current'  || return $? # website down ?
}

function download_RefSeq {
	time lftp -c "open -e 'mirror -v -e --delete-first -I RELEASE_NUMBER /refseq/release/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I *.genomic.gbff.gz /refseq/release/complete/ ${1}' ftp://ftp.ncbi.nih.gov" || return $?
}

function download_RDP {

	# version number
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/releaseREADME.txt' || return $?

	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz' || return $?
	wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz' || return $?

	# old
	#wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/release11_1_Bacteria_unaligned.gb.gz'
	#wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/release11_1_Archaea_unaligned.gb.gz'
	#wget -v -N -P ${1} 'http://rdp.cme.msu.edu/download/release11_1_Fungi_unaligned.gb.gz'
}

function download_SEED {
	echo can not ftp, must extract painfully through SEED API
	exit 1
	#time lftp -c "open -e 'mirror -v --no-recursion -I SEED.fasta /misc/Data/idmapping/ ${1}' ftp://ftp.theseed.org"
	#time lftp -c "open -e 'mirror -v --no-recursion -I subsystems2role.gz /subsystems/ ${1}' ftp://ftp.theseed.org"
}

function download_SILVA {
	time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/ ${1}' ftp://ftp.arb-silva.de" || return $?
	#wget -v -N -P ${1} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/lsu-parc.fasta.tgz'
	#wget -v -N -P ${1} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/lsu-parc.rast.tgz'
	#wget -v -N -P ${1} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/ssu-parc.fasta.tgz'
	#wget -v -N -P ${1} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/ssu-parc.rast.tgz'
}

function download_UniProt {
	time lftp -c "open -e 'mirror -v -e --delete-first -I reldate.txt  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_sprot.dat.gz  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_trembl.dat.gz /pub/databases/uniprot/current_release/knowledgebase/complete/ ${1}' ftp.uniprot.org" || return $?
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



