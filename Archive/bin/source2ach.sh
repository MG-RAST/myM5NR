#!/bin/bash

# DOCUMENTATION
#
# Takes downloaded source files and converts them into .md52id2func files, that can be used to load data into the database.




if [ $# -ne 3 ]
then
	echo "USAGE: source2ach.sh <threads> <sources_directory> <output_dir>  2>&1 | tee logfile1.txt"
	echo ""
	echo "<threads> number of threads to use, required (e.g. cat /proc/cpuinfo | grep processor)"
	echo "<sources_directory> input directory that contains the downloaded sources"
	echo "<output_dir> output directory"
	echo ""
	exit 1
fi

THREADS=${1}
SOURCES_DIR=${2%/} # will remove trailing slash
OUTPUT_DIRECTORY=${3%/}

#ALL_SOURCES=${@:4}

if [ ! -d "$SOURCES_DIR" ]; then
	echo "error: sources directory not found"
	exit 1
fi

if [ ! -d "$OUTPUT_DIRECTORY" ]; then
	echo "error: output directory not found"
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


OUTPUT_EXIST=""
OUTPUT_GOOD=""
OUTPUT_BAD=""
SOURCE_MISSING=""


# developer notes: *** READ THIS ***
# ls raw/RefSeq/* | xargs -n1 -P8 -I {} gunzip {}
# perl -s enables rudimentary switch parsing for switches on the command line after the program name

###########################################################
# source2ach functions (proteins and rna)

# ${1} input
# ${2} output


set -x


### proteins ###

#TODO: why are RefSeq and GenbankNR in directory NCBI?


function source2ach_eggNOG {
	# this includes COG annotations
	PARSED_UNIPROT="${1}/../../Parsed/UniProt/"
	[ -d ${PARSED_UNIPROT} ]  || return $?


	perl -s -e 'foreach(`zcat -f $input`) {chomp $_; @x = split(/\t/,$_); $id = shift @x; $map{$id} = [@x];} foreach(`cat $md52id2func`) {chomp $_; @z = split(/\t/,$_); if(exists $map{$z[1]}) {foreach $id (@{$map{$z[1]}}) {($src) = ($id =~ /^([A-Za-z]+)/); unless($src =~ /^[NC]OG$/){next;} print join("\t", ($z[0], $id, $z[2], $src))."\n";}}}' -- -input=${1}/UniProtAC2eggNOG.3.0.tsv.gz -md52id2func=${PARSED_UNIPROT}/\*.md52id2func  | sort -u > ${2}/eggNOG.md52id2ont.tmp || return $?

	[ -s ${2}/eggNOG.md52id2ont.tmp ] || return $?

	perl -s -e 'foreach(`zcat $descrCOG $descrNOG`) {chomp $_; ($id, $func) = split(/\t/,$_); if($func){$map{$id} = $func;}} foreach(`cat $output`) {chomp $_; @z = split(/\t/,$_); if(exists $map{$z[1]}) {$z[2] = $map{$z[1]};} print join("\t", @z)."\n";}' -- -descrCOG=${1}/COG.description.txt.gz -descrNOG=${1}/NOG.description.txt.gz -output=${2}/eggNOG.md52id2ont.tmp | sort -u > ${2}/eggNOG.md52id2ont || return $?

	[ -s ${2}/eggNOG.md52id2ont ] || return $?
	rm -f ${2}/eggNOG.md52id2ont.tmp

	$BIN/create_eggnog_hierarchies.pl --func ${1}/fun.txt --cat ${1}/COG.funccat.txt --cat ${1}/NOG.funccat.txt --desc ${1}/COG.description.txt --desc ${1}/NOG.description.txt > ${2}/hierarchies/eggNOG.hierarchy || return $?

	# eggNOG protein sequences
	mkdir -p ${2}/tmp/
	tar xvzf ${1}/sequences.v3.tar.gz  -C ${2}/tmp/ || return $?

	$BIN/source2ach.py -v -f fasta -p ${THREADS} -d ${2} eggNOG ${2}/tmp/*.fa || return $?

	rm -f ${2}/tmp/*
	rmdir -f ${2}/tmp/
}


function source2ach_CAZy {
	$BIN/cazy_ftable2m5nr_file.pl --file=cazy_all_v042314.txt --mappingFile=${2}/cazy_all_v042314.md52id2func --aliasFile=${2}/cazy_all_v042314.alias --batch || return $?
}

function source2ach_RefSeq {
	$BIN/source2ach.py -v -t -c -o -f genbank -p ${THREADS} -d ${2} RefSeq ${1}/*.genomic.gbff.gz || return $?
}

function source2ach_GenBankNR {
	$BIN/source2ach.py -v -n gb -f nr -p 1 -d ${2} GenBankNR ${1}/nr.gz || return $?
}

function source2ach_UniProt {
	$BIN/source2ach.py -v -o -f swiss -p 1 -d ${2} SwissProt ${1}/uniprot_sprot.dat.gz || return $?
	$BIN/source2ach.py -v -o -f swiss -p 1 -d ${2} TrEMBL ${1}/uniprot_trembl.dat.gz || return $?
}

function source2ach_InterPro {
	# This has dependency on UniProt !
	SOURCE_UNIPROT="$(dirname ${1})/UniProt"
	$BIN/source2ach.py -v -f swiss -p 2 -i ${1}/names.dat -d ${2} InterPro ${SOURCE_UNIPROT}/uniprot_*.dat.gz || return $?
}

function source2ach_PATRIC {
	# --continue_on_error is enabled! There are issues with biopython parser parsing genbank (some qualifiers are missing in genbank file)
	$BIN/source2ach.py --continue_on_error --fix_front_dash -v -t -o -f genbank -p ${THREADS} -d ${2} PATRIC ${1}/*/*.gbf || return $?
}

function source2ach_IMG {
	#mkdir parsed/IMG
	#cd raw/IMG
	#ls | xargs -n1 -P8 -I {} tar -zxf {}
	#cd ../../
	#rm raw/IMG/*.gz
	$BIN/source2ach.py -v -a img -f fasta -p ${THREADS} -d ${2} IMG ${1}/*/*.genes.faa || return $?
}

function source2ach_SEED {
	#gunzip raw/SEED/subsystems2role.gz  ?????
	cp ${1}/SEED.md52id2func2org ${2}/ || return $?
	$BIN/source2ach.py -v -a seed -f fasta -p 1 -d ${2} SEED ${1}/all.faa.gz || return $?
}

function source2ach_Subsystems {
	cp ${1}/Subsystems.subsystem2role2seq ${2}/ || return $?
}

function source2ach_Phantome {
	$BIN/source2ach.py -v -a phantome -f fasta  -p 1 -d ${2} Phantome ${1}/phage_proteins.fasta.gz || return $?
}



### rna ###

function source2ach_RDP {
	$BIN/source2ach.py -v -t -f genbank -p 3 -d ${2} RDP ${1}/current*_unaligned.gb.gz || return $?
}

function source2ach_Greengenes {
	$BIN/source2ach.py -v -t -a greengenes -f fasta -p 1 -d ${2} Greengenes ${1}/current_GREENGENES_gg16S_unaligned.fasta.gz || return $?
}

function source2ach_SILVA {

	$BIN/source2ach.py -v -a organism -f fasta -p 1 -d ${2} LSU ${1}/SILVA_???_LSUParc_tax_silva_trunc.fasta.gz || return $?
	$BIN/source2ach.py -v -a organism -f fasta -p 1 -d ${2} SSU ${1}/SILVA_???_LSURef_tax_silva_trunc.fasta.gz || return $?

	perl -e 'foreach(`zcat ${1}/rast/SILVA_???_LSUParc.rast.gz`){chomp $_; @x = split(/\t/,$_); if(scalar(@x) && ($x[0] =~ /^(\S+)\s+/)){print $1."\t".$x[1].$x[2]."\n";}}' > ${2}/LSU.id2tax  || return $?
	# return if file does not exist or if empty ; -s=file is not zero size
	if [ ! -s ${2}/LSU.id2tax ]
	then
		echo "${2}/LSU.id2tax has not been created"
		return 1
	fi

	perl -e 'foreach(`zcat ${1}/rast/SILVA_???_SSUParc.rast.gz`){chomp $_; @x = split(/\t/,$_); if(scalar(@x) && ($x[0] =~ /^(\S+)\s+/)){print $1."\t".$x[1].$x[2]."\n";}}' > ${2}/SSU.id2tax  || return $?
	if [ ! -s ${2}/SSU.id2tax ]
	then
		return 1
	fi

}

function source2ach_FungiDB {
	$BIN/source2ach.py -v -t -a vamps -f fasta -p 1 -d ${2} ITS ${1}/fungalITSdatabaseID.taxonomy.seqs.gz || return $?
}












## MO
# mkdir parsed/MO
# ls raw/MO/*.gz | xargs -n1 -P8 -I {} gunzip {}
# $BIN/source2ach.py -v -t -o -f genbank -p 8 -d parsed/MO MO raw/MO/*.gbk


## KBase
#mkdir raw/KBase parsed/KBase
#cd raw/KBase
#cp $BIN/seed_from_cdmi.pl .
#./seed_from_cdmi.pl
#cp md52seq ../../parsed/KBase/KBase.md52seq
#cp md52id2func2org ../../parsed/KBase/KBase.md52id2func
#cd ../../

## SEED
#cd parsed/KBase
#cp $BIN/kb2fig.py .
#./kb2fig.py < KBase.md52id2func > SEED.md52id2func
#cd ../..

## Subsystems
#cp raw/KBase/id2subsystems hierarchies/SEED.id2subsystems.new
#cp raw/KBase/ssclass hierarchies/ssclass
#cd hierarchies

## if have old seed table with ids -> SEED.id2subsystems.old ##
############# crazy hackage
#perl -e '%ss = (); foreach(`cat ssclass`){chomp $_; ($l1, $l2, $s) = split(/\t/, $_);  $s =~ s/_/ /g; $ss{$s} = $l1."\t".$l2;} foreach(`cat SEED.id2subsystems.new`){ chomp $_; @x = split(/\t/,$_); if(exists($ss{$x[1]})){ print $ss{$x[1]}."\t".$x[1]."\t".$x[2]."\n"; }}' > SEED.id2subsystems.new.full

#perl -e '%idmap = (); foreach(`cat SEED.id2subsystems.old`){chomp $_; ($ann, $id) = ($_ =~ /^(.*)\t(SS\d+)$/); $idmap{$ann} = $id;} foreach(`cat SEED.id2subsystems.new.full`){chomp $_; if(exists $idmap{$_}){print $_."\t".$idmap{$_}."\n";}}' > SEED.id2subsystems.id

#perl -e '%idmap = (); foreach(`cat SEED.id2subsystems.old`){chomp $_; ($ann, $id) = ($_ =~ /^(.*)\t(SS\d+)$/); $idmap{$ann} = $id;} foreach(`cat SEED.id2subsystems.new.full`){chomp $_; if(! exists $idmap{$_}){print $_."\n";}}' > SEED.id2subsystems.noid

#NEXTID = `cut -f5 SEED.id2subsystems.old | sort -n | tail -1` + 1 = 22075
#LASTID = NEXTID + `wc -l SEED.id2subsystems.noid` - 1 = 25207

#perl -e '$x = 0; @lines=`cat SEED.id2subsystems.noid`; chomp @lines; for $n ("NEXTID".."LASTID"){print $lines[$x]."\tSS".$n."\n"; $x += 1;}' > SEED.id2subsystems.noid.id
#cat SEED.id2subsystems.id SEED.id2subsystems.noid.id > SEED.id2subsystems
############

## Subsystems
#cd raw/KBase
#cp md52id2ontology ../../parsed/KBase/Subsystems.md52id2ont
#perl -e '%x = (); foreach(`cat ../../hierarchies/SEED.id2subsystems`){chomp $_; @z = split(/\t/, $_); $x{$z[3]} = $z[4];} foreach(`cat Subsystems.md52id2ont`){chomp $_; @z = split(/\t/, $_); if(exists($x{$z[2]})){print $z[0]."\t".$x{$z[2]}."\t".$z[2]."\tSubsystems\n";}}' > Subsystems.md52id2ont.ids
#mv Subsystems.md52id2ont.ids Subsystems.md52id2ont

#gunzip raw/KBase/subsystems2role.gz
#$BIN/source2ach.py -v -a seed -f fasta -d parsed/KBase KBase raw/KBase/KBase.fasta
#$BIN/seed_md52ontology.pl -v -s raw/KBase/subsystems2role -m parsed/KBase/KBase.md52id2func -d parsed/KBase


# KEGG is no longer available
#mkdir parsed/KEGG
#mv raw/KEGG/genome raw/kegg.genome
#tar -zxvf raw/KEGG/genes.tar.gz -C raw/KEGG
#rm raw/KEGG/genes.tar.gz
#$BIN/source2ach.py -v -o -k raw/kegg.genome -f kegg -p 8 -d parsed/KEGG KEGG raw/KEGG/*




set +x

###########################################################

for i in ${SOURCES}
do
	inputdir=${SOURCES_DIR}/${i}
	echo "inputdir=$inputdir"
	echo "check $i"


	if [ ! -d "${inputdir}" ]; then
		echo "${inputdir} not found!?" `date`
		OUTPUT_BAD="${SOURCE_MISSING} ${i}"
		continue
	fi

	OUTDIR="${OUTPUT_DIRECTORY}/${i}"
	OUTDIR_PART="${OUTPUT_DIRECTORY}/${i}_part"

	echo OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY}"
	echo OUTDIR="${OUTDIR}"
	echo OUTDIR_PART="${OUTDIR_PART}"

	if [ ! -d "${OUTDIR}" ]; then
		rm -rf ${OUTDIR_PART}
		mkdir -m 775 ${OUTDIR_PART}

		echo "Parsing ${i} and save results in ${OUTDIR_PART}"

		set -x
		# this is the function call. It will (should) stop the script if download fails.
		source2ach_${i} ${inputdir} ${OUTDIR_PART}
		PARSE_RESULT=$?
		set +x
		if [ ${PARSE_RESULT} -ne 0 ] ; then
			echo "parsing ${i} failed with exit code ${PARSE_RESULT}"
			OUTPUT_BAD="${OUTPUT_BAD} ${i}"
		else
			echo "parsing ${i} was succesful"
			OUTPUT_GOOD="${OUTPUT_GOOD} ${i}"
			# this confirms download was successful
			echo "mv ${OUTDIR_PART} $OUTDIR_DIR}"
			mv ${OUTDIR_PART} ${OUTDIR}
		fi
	else
		OUTPUT_EXIST="${OUTPUT_EXIST} ${i}"
	fi
	echo "State of parsing:"
	echo "OUTPUT_EXIST=${OUTPUT_EXIST}"
	echo "OUTPUT_GOOD=${OUTPUT_GOOD}"
	echo "OUTPUT_BAD=${OUTPUT_BAD}"
	echo "SOURCE_MISSING=${SOURCE_MISSING}"

done

echo Done `date`



