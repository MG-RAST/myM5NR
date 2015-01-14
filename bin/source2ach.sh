#!/bin/sh

# DOCUMENTATION
#
# Takes downloaded source files and converts them into .md52id2func files, that can be used to load data into the database.

##SOURCES="InterPro UniProt RefSeq SILVA Greengenes GenbankNR PATRIC RDP COGs(?) Phantome SEED"


###sources where we use archived version:
##STATIC="Cazy KEGG IMG FungiDB eggNOG"



#developer notes:
#for testing: SOURCES="test1 test2"



if [ $# -ne 2 ]
then
	echo "USAGE: source2ach.sh <sources_directory> <output_dir>"
	echo "<sources_directory> directory that conatins individual source download directories, this is input"
	echo "<output_dir> output directory"
	exit 1
fi

SOURCES_DIR=${1%/} # will remove trailing slash
OUTPUT_DIRECTORY=${1%/}

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


OUTPUT_EXIST=""
OUTPUT_GOOD=""
OUTPUT_BAD=""


###########################################################
# source2ach functions (proteins and rna)

# ${1} input
# ${2} output


set -x


### proteins ###

#TODO: why are RefSeq and GenbankNR in directory NCBI?

function source2ach_RefSeq {
	#mkdir parsed/NCBI
	#ls raw/RefSeq/* | xargs -n1 -P8 -I {} gunzip {}
	$BIN/source2ach.py -v -t -c -o -f genbank -p 8 -d parsed/NCBI RefSeq ${1}/*

}

function source2ach_GenbankNR {
	#gunzip raw/NR/nr.gz
	$BIN/source2ach.py -v -n gb -f nr -p 1 -d parsed/NCBI GenBank ${1}/nr
}

function source2ach_UniProt {
	mkdir parsed/UniProt
	gunzip raw/UniProt/uniprot_sprot.dat.gz
	gunzip raw/UniProt/uniprot_trembl.dat.gz
	$BIN/source2ach.py -v -o -f swiss -p 1 -d ${2} SwissProt ${1}/uniprot_sprot.dat
	$BIN/source2ach.py -v -o -f swiss -p 1 -d ${2} TrEMBL ${1}/uniprot_trembl.dat
}

function source2ach_InterPro {
	mkdir parsed/InterPro
	$BIN/source2ach.py -v -f swiss -p 2 -i ${1}/names.dat -d ${2} InterPro ${1}/uniprot_*.dat
}

function source2ach_PATRIC {
	mkdir parsed/PATRIC
	$BIN/source2ach.py -v -t -o -f genbank -p 8 -d ${2} PATRIC ${1}/*/*.gbf
}

function source2ach_IMG {
	#mkdir parsed/IMG
	#cd raw/IMG
	#ls | xargs -n1 -P8 -I {} tar -zxf {}
	#cd ../../
	#rm raw/IMG/*.gz
	$BIN/source2ach.py -v -a img -f fasta -p 8 -d ${2} IMG ${1}/*/*.genes.faa
}

function source2ach_SEED {
	#mkdir parsed/SEED
	#gunzip raw/SEED/subsystems2role.gz
	$BIN/source2ach.py -v -a seed -f fasta -d ${2} SEED ${1}/SEED.fasta
}

function source2ach_Phantome {
	#mkdir parsed/Phantome
	gunzip raw/Phantome/phage_proteins_1317466802.fasta.gz
	#Andi $BIN/source2ach.py -v -a phantome -f fasta  -p 1 -d ${2} Phantome ${1}/phage_proteins_1364814002.fasta
	#Travis $BIN/source2ach.py -v -a phantome -f fasta  -p 1 -d ${2} Phantome ${1}/phage_proteins.fasta
}



### rna ###

function source2ach_RDP {
	mkdir parsed/RDP
	gunzip raw/RDP/release*_unaligned.gb.gz
	$BIN/source2ach.py -v -t -f genbank -p 3 -d ${2} RDP ${1}/release*_unaligned.gb
}

function source2ach_Greengenes {
	mkdir parsed/Greengenes
	gunzip raw/Greengenes/current_GREENGENES_gg16S_unaligned.fasta.gz
	$BIN/source2ach.py -v -t -a greengenes -f fasta -p 1 -d ${2} Greengenes ${1}/current_GREENGENES_gg16S_unaligned.fasta
}

function source2ach_SILVA {
	mkdir parsed/SILVA
	tar -zxvf raw/SILVA/* -C raw/SILVA
	$BIN/source2ach.py -v -a organism -f fasta -p 1 -d ${2} LSU ${1}/lsu-parc.fasta
	$BIN/source2ach.py -v -a organism -f fasta -p 1 -d ${2} SSU ${1}/ssu-parc.fasta
# TODO replace raw/SILVA with ${1}
	perl -e 'foreach(`cat raw/SILVA/lsu-parc.rast`){chomp $_; @x = split(/\t/,$_); if(scalar(@x) && ($x[0] =~ /^(\S+)\s+/)){print $1."\t".$x[1].$x[2]."\n";}}' > ${2}/LSU.id2tax
	perl -e 'foreach(`cat raw/SILVA/ssu-parc.rast`){chomp $_; @x = split(/\t/,$_); if(scalar(@x) && ($x[0] =~ /^(\S+)\s+/)){print $1."\t".$x[1].$x[2]."\n";}}' > ${2}/SSU.id2tax
}

function source2ach_FungiDB {
	mkdir parsed/FungiDB
	gunzip raw/FungiDB/fungalITSdatabaseID.taxonomy.seqs.gz
	$BIN/source2ach.py -v -t -a vamps -f fasta -p 1 -d ${2} ITS ${1}/fungalITSdatabaseID.taxonomy.seqs
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

# eggNOG
#mkdir parsed/eggNOG
#gunzip raw/eggNOG/*
#perl -e 'foreach(`cat raw/eggNOG/UniProtAC2eggNOG.3.0.tsv`) {chomp $_; @x = split(/\t/,$_); $id = shift @x; $map{$id} = [@x];} foreach(`cat parsed/UniProt/*.md52id2func`) {chomp $_; @z = split(/\t/,$_); if(exists $map{$z[1]}) {foreach $id (@{$map{$z[1]}}) {($src) = ($id =~ /^([A-Za-z]+)/); unless($src =~ /^[NC]OG$/){next;} print join("\t", ($z[0], $id, $z[2], $src))."\n";}}}' | sort -u > parsed/eggNOG/eggNOG.md52id2ont.tmp
#perl -e 'foreach(`cat raw/eggNOG/*.description.txt`) {chomp $_; ($id, $func) = split(/\t/,$_); if($func){$map{$id} = $func;}} foreach(`cat parsed/eggNOG/eggNOG.md52id2ont.tmp`) {chomp $_; @z = split(/\t/,$_); if(exists $map{$z[1]}) {$z[2] = $map{$z[1]};} print join("\t", @z)."\n";}' | sort -u > parsed/eggNOG/eggNOG.md52id2ont
#rm parsed/eggNOG/eggNOG.md52id2ont.tmp
#$BIN/create_eggnog_hierarchies.pl --func raw/eggNOG/fun.txt --cat raw/eggNOG/COG.funccat.txt --cat raw/eggNOG/NOG.funccat.txt --desc raw/eggNOG/COG.description.txt --desc raw/eggNOG/NOG.description.txt > hierarchies/eggNOG.hierarchy





set +x

###########################################################

# iterate over all source dirs
for inputdir in $(ls -d ${SOURCES_DIR}/*/)
do
	i=${inputdir%%/}
	echo "check $i"

	if [ ! -d "${inputdir}" ]; then
		echo "${inputdir} not found!?" `date`
		exit 1
	fi

	OUTDIR=${OUTPUT_DIRECTORY}/$i
	OUTDIR_PART=${OUTPUT_DIRECTORY}/$i_part

	if [ ! -d "${OUTDIR}" ]; then
		rm -rf ${OUTDIR_PART}
		mkdir -m 775 ${OUTDIR_PART}

		echo "Parsing ${i} and save results in ${OUTDIR_PART}"

		set -x
		# this is the function call. It will (should) stop the script if download fails.
		echo source2ach_${i} ${inputdir} ${OUTDIR_PART}
		PARSE_RESULT=$?
		PARSE_RESULT=1
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
		echo "State of parsing:"
		echo "OUTPUT_EXIST=${OUTPUT_EXIST}"
		echo "OUTPUT_GOOD=${OUTPUT_GOOD}"
		echo "OUTPUT_BAD=${OUTPUT_BAD}"
	else
		OUTPUT_EXIST="${OUTPUT_EXIST} ${i}"
	fi

done

echo Done `date`



