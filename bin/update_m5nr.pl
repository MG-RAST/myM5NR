#!/usr/bin/perl


# read ${BIN}/../sources.cfg


sub systemp {
	
	my $cmd = join(' ', @_);
	print $cmd."\n";
	my $ret=system(@_);
	if ($ret != 0) {
		$ret >> 8
		print "Command \"$cmd\" failed with an exit code of $ret.\n";
		return 1
	}
	return 0
}


# empty string is an error
sub systemc {
	
	my $cmd = join(' ', @_);
	
	print $cmd."\n";

	local $/ = undef;
	open(my $COMMAND, "-|", $cmd)
	or die "Can't start command $cmd: $!";

	my $result = <$COMMAND>;
	
	unless close($COMMAND) {
		print STDERR "returned with error:\n";
		if (defined $result) {
			print STDERR "$result\n";
		}
		return "";
	};
	return $result;
}







###########################################################
# download functions

# $dir is the "..._part" download directory, specific to individual source




#### proteins




f->{'CAZy'}->{'download'} = sub {
	my $dir = shift(@_);
	
	systemp("${BIN}/get_cazy_table.pl ${dir}/cazy_all_v042314.txt") == 0 || return;
};


f->{'eggNOG'}->{'download'} = sub {
	my $dir = shift(@_);
	
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
	systemp(qq[time lftp -c "open -e 'mirror -v -e --no-recursion \\
		-I fun.txt.gz \\
		-I UniProtAC2eggNOG.3.0.tsv.gz \\
		-I COG.funccat.txt.gz \\
		-I NOG.funccat.txt.gz \\
		-I COG.description.txt.gz \\
		-I NOG.description.txt.gz \\
		-I sequences.v3.tar.gz \\
		/eggNOG/3.0/ $dir' ftp://eggnog.embl.de" ])== 0 || return;



};


f->{'COGs'}->{'download'} = sub {
	my $dir = shift(@_);
	systemp(qq[time lftp -c "open -e 'mirror -v --no-recursion /pub/COG/COG2014/data/ $dir' ftp://ftp.ncbi.nih.gov"]);
};
		
f->{'FungiDB'}->{'download'} = sub {
	my $dir = shift(@_);
	# use old version, does not seem to be updated anymore
	printf "Please use archived version for FungiDB.\n";
	#return 1
	#wget -v -N -P $dir 'http://fungalgenomes.org/public/mobedac/for_VAMPS/fungalITSdatabaseID.taxonomy.seqs.gz' || return $?
};

f->{'IMG'}->{'download'} = sub {
	my $dir = shift(@_);
	printf "Please use archived version for IMG.\n";
	#echo "ftp path is missing (copy archived version)"
	#time lftp -c "open -e 'mirror -v --no-recursion -I img_core_v400.tar /pub/IMG/ $dir' ftp://ftp.jgi-psf.org"
};
		
f->{'InterPro'}->{'download'} = sub {
	my $dir = shift(@_);

	# see release_notes.txt for version
	systemp(qq[time lftp -c "open -e 'mirror -v --no-recursion /pub/databases/interpro/Current/ $dir' ftp://ftp.ebi.ac.uk"])== 0 || return;
	systemp(qq[cat $dir/release_notes.txt | grep "Release [0-9]" | grep -o "[0-9]*\.[0-9]*" > $dir/version.txt]) == 0 || return;
};

f->{'KEGG'}->{'download'} = sub {
	my $dir = shift(@_);
	die("KEGG is no longer available.");
	return 1
	#time lftp -c "open -e 'mirror -v --no-recursion -I genome /pub/kegg/genes/ $dir' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I genes.tar.gz /pub/kegg/release/current/ $dir' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I ko /pub/kegg/genes/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --parallel=2 -I *.keg /pub/kegg/brite/ko/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
};

f->{'MO'}->{'download'} = sub {
	my $dir = shift(@_);
	# we are not using this MG right now.
	# issue with recursive wget and links on page, this hack works
	#for i in `seq 1 907348`; do wget -N -P $dir http://www.microbesonline.org/genbank/${i}.gbk.gz 2> /dev/null; done
	#wget -v -N -P $dir http://www.microbesonline.org/genbank/10000550.gbk.gz
};

f->{'GenBankNR'}->{'download'} = sub {
	my $dir = shift(@_);
	systemp(qq[time lftp -c "open -e 'mirror -v -e --no-recursion -I nr.gz /blast/db/FASTA/ $dir' ftp://ftp.ncbi.nih.gov"]) == 0 || return;
	systemp(qq[stat -c '%y' $dir/nr.gz | cut -c 1-4,6,7,9,10 > $dir/version.txt ]) == 0 || return;
};

f->{'PATRIC'}->{'download'} = sub {
	my $dir = shift(@_);
	systemp(qq[time lftp -c "open -e 'mirror -v --parallel=2 -I *.PATRIC.gbf /patric2/genomes/ $dir' http://brcdownloads.vbi.vt.edu" ]) == 0 || return;
	# use one of the directories time stamp
	systemp(qq[stat -c '%y' $dir/1000561.3 | cut -c 1-4,6,7,9,10 > $dir/version.txt]) == 0 || return;
};

f->{'Phantome'}->{'version'} = sub {

	my $timestamp=systemc(qq(curl http://www.phantome.org/Downloads/proteins/all_sequences/ | grep -o phage_proteins_[0-9]*.fasta.gz | sort | tail -n 1 | grep -o "[0-9]*"));
	
	my $version = systemc(qq[date -d @$timestamp +"%Y%m%d"]);
	
	return $version;
};

f->{'Phantome'}->{'download'} = sub {
	my $dir = shift(@_);
	
	#find node
	#curl "http://shock.metagenomics.anl.gov/node?query&type=data-library&project=M5NR&data-library-name=M5NR_source_Phantome"
	SOURCE=`basename $dir`
	OLD_NODE=`curl "http://shock.metagenomics.anl.gov/node?query&type=data-library&project=M5NR&data-library-name=M5NR_source_${SOURCE}&version=20150403" | grep -o "[0-f]\{8\}-[0-f]\{4\}-[0-f]\{4\}-[0-f]\{4\}-[0-f]\{12\}"`
	
	if [ ${OLD_NODE} ne "" ] ; then
		#download from shock?
		echo found shock node
		return
	fi
	
	wget -v -N -P $dir "http://www.phantome.org/Downloads/proteins/all_sequences/phage_proteins_${TIMESTAMP}.fasta.gz"  || return $?
	echo "$VERSION" > $dir/version.txt
	
};

f->{'RefSeq'}->{'download'} = sub {
	my $dir = shift(@_);
	time lftp -c "open -e 'mirror -v -e --delete-first -I RELEASE_NUMBER /refseq/release/ $dir' ftp://ftp.ncbi.nih.gov" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I *.genomic.gbff.gz /refseq/release/complete/ $dir' ftp://ftp.ncbi.nih.gov" || return $?
	cp $dir/RELEASE_NUMBER $dir/version.txt
};


f->{'SEED'}->{'download'} = sub {
	my $dir = shift(@_);


	CURRENT_VERSION=`curl ftp://ftp.theseed.org//SeedProjectionRepository/Releases/ | grep "\.current" | grep -o "[0-9]\{4\}\.[0-9]*"`

	time ${BIN}/querySAS.pl -source SEED  1> $dir/SEED.md52id2func2org || return $?
	time lftp -c "open -e 'mirror -v /SeedProjectionRepository/Releases/ProblemSets.${CURRENT_VERSION}/ $dir' ftp://ftp.theseed.org" || return $?

	echo ${CURRENT_VERSION} > $dir/version.txt

	#old:
	#time lftp -c "open -e 'mirror -v --no-recursion -I SEED.fasta /misc/Data/idmapping/ $dir' ftp://ftp.theseed.org"
	#time lftp -c "open -e 'mirror -v --no-recursion -I subsystems2role.gz /subsystems/ $dir' ftp://ftp.theseed.org"
};

f->{'Subsystems'}->{'download'} = sub {
	my $dir = shift(@_);
	time ${BIN}/querySAS.pl --source=Subsystems --output=$dir/Subsystems.subsystem2role2seq || return $?
};
f->{'UniProt'}->{'download'} = sub {
	my $dir = shift(@_);
	time lftp -c "open -e 'mirror -v -e --delete-first -I reldate.txt  /pub/databases/uniprot/current_release/knowledgebase/complete/ $dir' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_sprot.dat.gz  /pub/databases/uniprot/current_release/knowledgebase/complete/ $dir' ftp.uniprot.org" || return $?
	time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_trembl.dat.gz /pub/databases/uniprot/current_release/knowledgebase/complete/ $dir' ftp.uniprot.org" || return $?
	head -n1 $dir/reldate.txt | grep -o "[0-9]\{4\}_[0-9]*" > $dir/version.txt
};


#### RNA
f->{'SILVA'}->{'download'} = sub {
	my $dir = shift(@_);
	time lftp -c "open -e 'mirror -v --no-recursion --dereference /current/Exports/ $dir' ftp://ftp.arb-silva.de" || return $?
	mkdir -p $dir/rast
	time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/rast $dir/rast' ftp://ftp.arb-silva.de" || return $?
	head -n 1 $dir/README.txt | grep -o "[0-9]\{3\}\.[0-9]*" > $dir/version.txt
};
f->{'RDP'}->{'download'} = sub {
	my $dir = shift(@_);

	# version number
	wget -v -N -P $dir 'http://rdp.cme.msu.edu/download/releaseREADME.txt' || return $?

	wget -v -N -P $dir 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz' || return $?
	wget -v -N -P $dir 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz' || return $?
	wget -v -N -P $dir 'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz' || return $?
	
	cp $dir/releaseREADME.txt $dir/version.txt
};
f->{'Greengenes'}->{'download'} = sub {
	my $dir = shift(@_);
	# from 2011 ?
	wget -v -N -P $dir 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz' || return $?
	# use filedata as version
	stat -c '%y' current_GREENGENES_gg16S_unaligned.fasta.gz | cut -c 1-4,6,7,9,10 > $dir/version.txt
};



###########################################################

#for i in ${SOURCES}
#do
#	echo "check $i"
#	SOURCE_DIR="${DOWNLOAD_DIR}/${i}"
#	SOURCE_DIR_PART="${DOWNLOAD_DIR}/${i}_part"
#	if [ ! -d "${SOURCE_DIR}" ]; then
#		echo "${SOURCE_DIR} not found. Downloading..." `date`
#		if [ -d "${SOURCE_DIR_PART}" ]; then
#			echo "${SOURCE_DIR_PART} download already exists. Please delete manually"
#			exit
#		fi
#		mkdir -m 775 ${SOURCE_DIR_PART}
#
#		echo "Downloading ${i} to ${SOURCE_DIR_PART}"
#
#		set -x
#		# this is the function call. It will (should) stop the script if download fails.
#		download_${i} ${SOURCE_DIR_PART}
#		echo `date +"%Y%m%d"` > ${SOURCE_DIR_PART}/timestamp.txt
#		DOWNLOAD_RESULT=$?
#		set +x
#		if [ ${DOWNLOAD_RESULT} -ne 0 ] ; then
#			echo "downloading ${i} failed with exit code ${DOWNLOAD_RESULT}"
#			DOWNLOADS_BAD="${DOWNLOADS_BAD} ${i}"
#		else
#			echo "downloading ${i} was succesful"
#			DOWNLOADS_GOOD="${DOWNLOADS_GOOD} ${i}"
#			# this confirms download was successful
#			echo "mv ${SOURCE_DIR_PART} ${SOURCE_DIR}"
#			mv ${SOURCE_DIR_PART} ${SOURCE_DIR}
#		fi
#		echo "State of downloads:"
#		echo "DOWNLOADS_EXIST=${DOWNLOADS_EXIST}"
#		echo "DOWNLOADS_GOOD=${DOWNLOADS_GOOD}"
#		echo "DOWNLOADS_BAD=${DOWNLOADS_BAD}"
#	else
#		DOWNLOADS_EXIST="${DOWNLOADS_EXIST} ${i}"
#	fi
#
#done
#
#echo Done `date`



