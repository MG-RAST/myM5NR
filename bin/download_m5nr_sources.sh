#!/bin/sh



SOURCES="InterPro UniProt RefSeq SILVA"

# all:
#SOURCES="eggNOG FungiDB Greengenes IMG InterPro KEGG MO NR PATRIC Phantome RefSeq RDP SEED SILVA UniProt"


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

set -e
# Die on error. When a download fails, the bash script stops and the _part download directory will not be renamed.
# This also means we do not have to check the return values of our download functions for success our failure.


###########################################################
# download functions

# ${1} is name of source
# ${2} is download directory, specific to individual source

function download_eggNOG {
	wget -v -N -P ${2} 'http://eggnog.embl.de/version_3.0/data/downloads/fun.txt.gz'
	wget -v -N -P ${2} 'http://eggnog.embl.de/version_3.0/data/downloads/UniProtAC2eggNOG.3.0.tsv.gz'
	wget -v -N -P ${2} 'http://eggnog.embl.de/version_3.0/data/downloads/COG.funccat.txt.gz'
	wget -v -N -P ${2} 'http://eggnog.embl.de/version_3.0/data/downloads/NOG.funccat.txt.gz'
	wget -v -N -P ${2} 'http://eggnog.embl.de/version_3.0/data/downloads/COG.description.txt.gz'
	wget -v -N -P ${2} 'http://eggnog.embl.de/version_3.0/data/downloads/NOG.description.txt.gz'
}

function download_FungiDB {
	wget -v -N -P ${2} 'http://fungalgenomes.org/public/mobedac/for_VAMPS/fungalITSdatabaseID.taxonomy.seqs.gz'
}

function download_Greengenes {
	wget -v -N -P ${2} 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz'
}


function download_IMG {
	echo ftp path is missing
	#time lftp -c "open -e 'mirror -v --no-recursion -I img_core_v400.tar /pub/IMG/ ${2}' ftp://ftp.jgi-psf.org"
}

function download_InterPro {
	time lftp -c "open -e 'mirror -v --no-recursion /pub/databases/interpro/Current/ ${2}' ftp://ftp.ebi.ac.uk"
	#time lftp -c "open -e 'mirror -v --no-recursion -I names.dat /pub/databases/interpro/Current/ ${2}' ftp://ftp.ebi.ac.uk"
}

function download_KEGG {
	echo ftp is no longer accessable
	#time lftp -c "open -e 'mirror -v --no-recursion -I genome /pub/kegg/genes/ ${2}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I genes.tar.gz /pub/kegg/release/current/ ${2}' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I ko /pub/kegg/genes/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --parallel=2 -I *.keg /pub/kegg/brite/ko/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
}

function download_MO {
	# issue with recursive wget and links on page, this hack works
	for i in `seq 1 907348`; do wget -N -P ${2} http://www.microbesonline.org/genbank/${i}.gbk.gz 2> /dev/null; done
	wget -v -N -P ${2} http://www.microbesonline.org/genbank/10000550.gbk.gz
}

function download_NR {
	time lftp -c "open -e 'mirror -v -e --no-recursion -I nr.gz /blast/db/FASTA/ ${2}' ftp://ftp.ncbi.nih.gov"
}

function download_PATRIC {
	time lftp -c "open -e 'mirror -v --parallel=2 -I *.PATRIC.gbf /patric2/genomes/ ${2}' http://brcdownloads.vbi.vt.edu"
}

function download_Phantome {
	wget -v -O ${2}/phage_proteins.fasta.gz 'http://www.phantome.org/Downloads/proteins/all_sequences/current'
}

function download_RefSeq {
	time lftp -c "open -e 'mirror -v -e --delete-first -I *.genomic.gbff.gz /refseq/release/complete/ ${2}' ftp://ftp.ncbi.nih.gov"
}

function download_RDP {
	wget -v -N -P ${2} 'http://rdp.cme.msu.edu/download/release11_1_Bacteria_unaligned.gb.gz'
	wget -v -N -P ${2} 'http://rdp.cme.msu.edu/download/release11_1_Archaea_unaligned.gb.gz'
	wget -v -N -P ${2} 'http://rdp.cme.msu.edu/download/release11_1_Fungi_unaligned.gb.gz'
}

function download_SEED {
	echo can not ftp, must extract painfully through SEED API
	#time lftp -c "open -e 'mirror -v --no-recursion -I SEED.fasta /misc/Data/idmapping/ ${2}' ftp://ftp.theseed.org"
	#time lftp -c "open -e 'mirror -v --no-recursion -I subsystems2role.gz /subsystems/ ${2}' ftp://ftp.theseed.org"
}

function download_SILVA {
	time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/ ${2}' ftp://ftp.arb-silva.de"
	#wget -v -N -P ${2} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/lsu-parc.fasta.tgz'
	#wget -v -N -P ${2} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/lsu-parc.rast.tgz'
	#wget -v -N -P ${2} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/ssu-parc.fasta.tgz'
	#wget -v -N -P ${2} 'http://www.arb-silva.de/fileadmin/silva_databases/release_108/Exports/ssu-parc.rast.tgz'
}

function download_UniProt {
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_sprot.dat.gz  /pub/databases/uniprot/current_release/knowledgebase/complete/ ${2}' ftp.uniprot.org"
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_trembl.dat.gz /pub/databases/uniprot/current_release/knowledgebase/complete/ ${2}' ftp.uniprot.org"
}



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
		download_${i} ${i} ${SOURCE_DIR_PART}


		# this confirms download was successful
		mv ${SOURCE_DIR_PART} ${SOURCE_DIR}
		set +x
	fi

done



exit 0


echo Starting Download for ACH `date`




echo Done `date`
