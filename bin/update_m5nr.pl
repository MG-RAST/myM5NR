#!/usr/bin/perl


# read ${BIN}/../sources.cfg

use Getopt::Long ;
use SHOCK::Client;
use Data::Dumper;
use Cwd;


my @sources_protein=('SEED', 'Subsystems', 'InterPro', 'UniProt', 'RefSeq', 'GenBankNR', 'PATRIC', 'Phantome', 'CAZy', 'KEGG', 'eggNOG'); #'IMG'

my @sources_rna=('SILVA', 'Greengenes', 'RDP', 'FungiDB');

my @sources=(@sources_protein, @sources_rna);





my $sc = new SHOCK::Client('http://shock.metagenomics.anl.gov', '', 0);









sub systemp {
	my $cmd = join(' ', @_);
	print $cmd."\n";
	my $ret=system(@_);
	if ($ret != 0) {
		$ret >> 8;
		print "Command \"$cmd\" failed with an exit code of $ret.\n";
		return 1;
	}
	return 0;
}


# empty string is an error
sub systemc {
	print "xxxxxxxx: ".$_[0]."\n";

	my $cmd = join(' ', @_);
	
	print "cmd: ".$cmd."\n";

	local $/ = undef;
	open(my $COMMAND, "-|", $cmd)
	or die "Can't start command $cmd: $!";

	my $result = <$COMMAND>;
	
	unless (close($COMMAND)) {
		print STDERR "returned with error.\n";
		if (defined $result) {
			print STDERR "result: \"$result\"\n";
		}
		return "";
	};
	
	# remove trailing newlines
	$result =~ s/\R*$//g;
	
	if ($result eq "") {
		print STDERR "result empty !?\n";
	}
	
	return $result;
}







###########################################################
# download functions

# $outdir is the "..._part" download directory, specific to individual source




#### proteins
$f->{'CAZy'}->{'online'} = 1;

$f->{'CAZy'}->{'version'} = sub {
	return "daily";
};


$f->{'CAZy'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	
	systemp("${BIN}/get_cazy_table.pl ${dir}/cazy_all_v042314.txt") == 0 || return;
};

$f->{'eggNOG'}->{'online'} = 0;
$f->{'eggNOG'}->{'version'} = sub {
	return "3.0";
};


$f->{'eggNOG'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	
	# version 4 available, but different format, thus we use old version for now.
	#echo "Using v3 not v4 yet"

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
		/eggNOG/3.0/ $outdir' ftp://eggnog.embl.de"])== 0 || return 1;



};

$f->{'COGs'}->{'online'} = 0;
$f->{'COGs'}->{'download'} = sub {
	
	### not used.
	
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	systemp(qq[time lftp -c "open -e 'mirror -v --no-recursion /pub/COG/COG2014/data/ $outdir' ftp://ftp.ncbi.nih.gov"])== 0 || return 1;
};

$f->{'FungiDB'}->{'online'} = 0;
$f->{'FungiDB'}->{'version'} = sub {
	return "20111019"
};

$f->{'FungiDB'}->{'download'} = sub {
	
	### new FungiDB ? http://fungidb.org/common/downloads/release-24/
	
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	# use old version, does not seem to be updated anymore
	print "Please use archived version for FungiDB.\n";
	#return 1
	#wget -v -N -P $outdir 'http://fungalgenomes.org/public/mobedac/for_VAMPS/fungalITSdatabaseID.taxonomy.seqs.gz' || return $?
};


$f->{'IMG'}->{'download'} = sub {
	
	# ignoring at the moment
	
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	print "Please use archived version for IMG.\n";
	#echo "ftp path is missing (copy archived version)"
	#time lftp -c "open -e 'mirror -v --no-recursion -I img_core_v400.tar /pub/IMG/ $outdir' ftp://ftp.jgi-psf.org"
};

$f->{'Interpro'}->{'online'} = 1;
$f->{'InterPro'}->{'version'} = sub {

	return systemc('curl --silent ftp://ftp.ebi.ac.uk//pub/databases/interpro/Current/release_notes.txt | grep "Release [0-9]\+" | grep -o "[0-9]\+\.[0-9]\+"');
	
};

$f->{'InterPro'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};

	# see release_notes.txt for version
	systemp(qq[time lftp -c "open -e 'mirror -v --no-recursion /pub/databases/interpro/Current/ $outdir' ftp://ftp.ebi.ac.uk"])== 0 || return 1;
	systemp(qq[cat $outdir/release_notes.txt | grep "Release [0-9]" | grep -o "[0-9]*\.[0-9]*" > $outdir/version.txt])== 0 || return 1;
};

$f->{'KEGG'}->{'online'} = 0;
$f->{'KEGG'}->{'version'} = sub {
	return "56";
};

$f->{'KEGG'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	die("KEGG is no longer available.");
	return 1
	#time lftp -c "open -e 'mirror -v --no-recursion -I genome /pub/kegg/genes/ $outdir' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I genes.tar.gz /pub/kegg/release/current/ $outdir' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --no-recursion -I ko /pub/kegg/genes/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
	#time lftp -c "open -e 'mirror -v --parallel=2 -I *.keg /pub/kegg/brite/ko/ ${DOWNLOAD_DIR}/KO' ftp://ftp.genome.ad.jp"
};

$f->{'MO'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	# we are not using this MG right now.
	# issue with recursive wget and links on page, this hack works
	#for i in `seq 1 907348`; do wget -N -P $outdir http://www.microbesonline.org/genbank/${i}.gbk.gz 2> /dev/null; done
	#wget -v -N -P $outdir http://www.microbesonline.org/genbank/10000550.gbk.gz
};

$f->{'GenBankNR'}->{'online'} = 1;
$f->{'GenBankNR'}->{'version'} = sub {
	# ugly: reads date from file
	
	print "OS: $^O\n";
	my $flag = '-d';
	if ($^O eq "darwin") {
		$flag = '-v ';
	}
	
	
	my $line = systemc('curl --silent ftp://ftp.ncbi.nih.gov/blast/db/FASTA/ | grep " nr.gz$"'); #
	if ( $line eq "" ) {
		print STDERR "Could not curl GenBankNR website\n";
		return "";
	}
	
	# example: -r--r--r--   1 ftp      anonymous 17023852553 Jul  6 05:36 nr.gz
	my ($timestring) = $line =~ /anonymous\s+\d+\s+(.*)\s+nr\.gz/;
	unless (defined $timestring) {
		print STDERR "Could not parse line \"$line\"\n";
		return "";
	}
	
	if ( $timestring eq "" ) {
		print STDERR "Could not parse line \"$line\"\n";
		return "";
	}
	
	
	return systemc(qq[date $flag "$timestring" '+%Y%m%d']);
};




$f->{'GenBankNR'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	systemp(qq[time lftp -c "open -e 'mirror -v -e --no-recursion -I nr.gz /blast/db/FASTA/ $outdir' ftp://ftp.ncbi.nih.gov"])== 0 || return 1;
	systemp(qq[stat -c '%y' $outdir/nr.gz | cut -c 1-4,6,7,9,10 > $outdir/version.txt ])== 0 || return 1;
};

$f->{'PATRIC'}->{'online'} = 1;
$f->{'PATRIC'}->{'version'} = sub {
	# ugly: reads date from file
	
	%mon2num = qw(
	jan 01  feb 02  mar 03  apr 04  may 05  jun 06
	jul 07  aug 08  sep 09  oct 10 nov 11 dec 12
	);
	
	# example: <a href="1000561.3.PATRIC.gbf">1000561.3.PATRIC.gbf</a>     21-Apr-2015 16:16      13503111
	my $line  = systemc('curl --silent http://brcdownloads.vbi.vt.edu/patric2/genomes/1000561.3/ | grep PATRIC.gbf');
	
	
	if ($line eq "" ) {
		return "";
	}
	
	my ($day, $month_str, $year) = $line =~ /(\d+)\-(\S+)\-(\d\d\d\d)/;
	
	
	unless (defined $year) {
		print STDERR "Error: Could not parse date from line ".$line."\n";
		return "";
	}
	
	my $month = $mon2num{lc($month_str)};
	
	unless (defined $month) {
		print STDERR "Error: Could not map month ".$month_str."\n";
		return "";
	}
	
	return $year.$month.$day;
};
	
$f->{'PATRIC'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	systemp(qq[time lftp -c "open -e 'mirror -v --parallel=2 -I *.PATRIC.gbf /patric2/genomes/ $outdir' http://brcdownloads.vbi.vt.edu" ])== 0 || return 1;
	# use one of the directories time stamp
	systemp(qq[stat -c '%y' $outdir/1000561.3 | cut -c 1-4,6,7,9,10 > $outdir/version.txt])== 0 || return 1;
};

$f->{'Phantome'}->{'online'} = 1;
$f->{'Phantome'}->{'version'} = sub {

	my $timestamp=systemc(qq(curl --silent http://www.phantome.org/Downloads/proteins/all_sequences/ | grep -o phage_proteins_[0-9]*.fasta.gz | sort | tail -n 1 | grep -o "[[:digit:]]\\+"));
	
	if ($timestamp eq "") {
		return "";
	}
	print "timestamp: \"$timestamp\"\n";
	
	print "OS: $^O\n";
	my $flag = '-d @';
	if ($^O eq "darwin") {
		$flag = '-r ';
	}
	
	my $teststr =qq[date $flag$timestamp +"%Y%m%d"] ; # -d -r
	print "test: $teststr\n";
	my $version = systemc($teststr);
	
	return $version;
};

$f->{'Phantome'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	
	#find node
	#curl "http://shock.metagenomics.anl.gov/node?query&type=data-library&project=M5NR&data-library-name=M5NR_source_Phantome"
	#SOURCE=`basename $outdir`
	#OLD_NODE=`curl "http://shock.metagenomics.anl.gov/node?query&type=data-library&project=M5NR&data-library-name=M5NR_source_${SOURCE}&version=20150403" | grep -o "[0-f]\{8\}-[0-f]\{4\}-[0-f]\{4\}-[0-f]\{4\}-[0-f]\{12\}"`
	
	#if [ ${OLD_NODE} ne "" ] ; then
		#download from shock?
	#	echo found shock node
	#	return
	#fi
	
	systemp(qq[wget -v -N -P $outdir "http://www.phantome.org/Downloads/proteins/all_sequences/phage_proteins_${TIMESTAMP}.fasta.gz"])== 0 || return 1;
	systemp(qq[echo "$VERSION" > $outdir/version.txt])== 0 || return 1;
	
};

$f->{'RefSeq'}->{'online'} = 1;
$f->{'RefSeq'}->{'version'} = sub {
	return systemc('curl --silent ftp://ftp.ncbi.nih.gov/refseq/release/RELEASE_NUMBER');
};

$f->{'RefSeq'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};
	systemp(qq[time lftp -c "open -e 'mirror -v -e --delete-first -I RELEASE_NUMBER /refseq/release/ $outdir' ftp://ftp.ncbi.nih.gov"])== 0 || return 1;
	systemp(qq[time lftp -c "open -e 'mirror -v -e --delete-first -I *.genomic.gbff.gz /refseq/release/complete/ $outdir' ftp://ftp.ncbi.nih.gov"])== 0 || return 1;
	systemp(qq[cp $outdir/RELEASE_NUMBER $outdir/version.txt])== 0 || return 1;
};


$f->{'SEED'}->{'online'} = 1;
$f->{'SEED'}->{'version'} = sub {
	# detectd symlink pointing to version
	# example: lrwxrwxrwx   1 ftp      ftp            19 Dec  9  2014 ProblemSets.current -> ProblemSets.2014.12
	return systemc(q(curl --silent ftp://ftp.theseed.org//SeedProjectionRepository/Releases/ | grep "\.current" | grep -o "[0-9]\{4\}\.[0-9]*"))
};
	
	
$f->{'SEED'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $bindir = $h->{'bindir'};
	my $version = $h->{'version'};

	systemp(qq[time ${BIN}/querySAS.pl -source SEED  1> $outdir/SEED.md52id2func2org])== 0 || return 1;
	systemp(qq[time lftp -c "open -e 'mirror -v /SeedProjectionRepository/Releases/ProblemSets.$version/ $outdir' ftp://ftp.theseed.org"])== 0 || return 1;

	systemp(qq[echo $version > $outdir/version.txt])== 0 || return 1;

	#old:
	#time lftp -c "open -e 'mirror -v --no-recursion -I SEED.fasta /misc/Data/idmapping/ $outdir' ftp://ftp.theseed.org"
	#time lftp -c "open -e 'mirror -v --no-recursion -I subsystems2role.gz /subsystems/ $outdir' ftp://ftp.theseed.org"
};


$f->{'Subsystems'}->{'online'} = 1;

$f->{'Subsystems'}->{'version'} = sub {
	return "daily";
};

$f->{'Subsystems'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $version = $h->{'version'};
	
	systemp(qq[${BIN}/querySAS.pl --source=Subsystems --output=$outdir/Subsystems.subsystem2role2seq])== 0 || return 1;
	
};


$f->{'UniProt'}->{'online'} = 1;
$f->{'UniProt'}->{'version'} = sub {

	#example reldate.txt:
	#UniProt Knowledgebase Release 2015_07 consists of:
	#UniProtKB/Swiss-Prot Release 2015_07 of 24-Jun-2015
	#UniProtKB/TrEMBL Release 2015_07 of 24-Jun-2015
	
	return systemc('curl --silent ftp://ftp.uniprot.org//pub/databases/uniprot/current_release/knowledgebase/complete/reldate.txt | head -n 1 | grep -o "[0-9]\{4\}_[0-9]\+"')


};

$f->{'UniProt'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $version = $h->{'version'};
	systemp(qq[time lftp -c "open -e 'mirror -v -e --delete-first -I reldate.txt  /pub/databases/uniprot/current_release/knowledgebase/complete/ $outdir' ftp.uniprot.org"])== 0 || return 1;
	systemp(qq[time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_sprot.dat.gz  /pub/databases/uniprot/current_release/knowledgebase/complete/ $outdir' ftp.uniprot.org"])== 0 || return 1;
	systemp(qq[time lftp -c "open -e 'mirror -v -e --delete-first -I uniprot_trembl.dat.gz /pub/databases/uniprot/current_release/knowledgebase/complete/ $outdir' ftp.uniprot.org"])== 0 || return 1;
	systemp(qq[head -n1 $outdir/reldate.txt | grep -o "[0-9]\{4\}_[0-9]*" > $outdir/version.txt])== 0 || return 1;
};


#### RNA
$f->{'SILVA'}->{'online'} = 1;
$f->{'SILVA'}->{'version'} = sub {

	# example: README for SILVA 119.1 export files
	my $line = systemc('curl --silent ftp://ftp.arb-silva.de//current/Exports/README.txt | head -n 1');

	if ($line eq "") {
		return "";
	}
	
	my ($version) = $line =~ /(\d+\.\d+)/;
	
	unless (defined $version) {
		print STDERR "error: could not parse line $line\n";
		return "";
	}
	
	return $version;
};


$f->{'SILVA'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $version = $h->{'version'};
	systemp(qq[time lftp -c "open -e 'mirror -v --no-recursion --dereference /current/Exports/ $outdir' ftp://ftp.arb-silva.de" ])== 0 || return 1;
	systemp(qq[mkdir -p $outdir/rast])== 0 || return 1;
	systemp(qq[time lftp -c "open -e 'mirror -v --no-recursion /current/Exports/rast $outdir/rast' ftp://ftp.arb-silva.de"])== 0 || return 1;
	systemp(qq[head -n 1 $outdir/README.txt | grep -o "[0-9]\{3\}\.[0-9]*" > $outdir/version.txt])== 0 || return 1;
};


$f->{'RDP'}->{'online'} = 1;
$f->{'RDP'}->{'version'} = sub {

	return systemc('curl --silent http://rdp.cme.msu.edu/download/releaseREADME.txt');

};

$f->{'RDP'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $version = $h->{'version'};

	# version number
	systemp(qq[wget -v -N -P $outdir 'http://rdp.cme.msu.edu/download/releaseREADME.txt'])== 0 || return 1;

	systemp(qq[wget -v -N -P $outdir 'http://rdp.cme.msu.edu/download/current_Bacteria_unaligned.gb.gz'])== 0 || return 1;
	systemp(qq[wget -v -N -P $outdir 'http://rdp.cme.msu.edu/download/current_Archaea_unaligned.gb.gz'])== 0 || return 1;
	systemp(qq[wget -v -N -P $outdir 'http://rdp.cme.msu.edu/download/current_Fungi_unaligned.gb.gz'])== 0 || return 1;
	
	systemp(qq[cp $outdir/releaseREADME.txt $outdir/version.txt])== 0 || return 1;
};

$f->{'Greengenes'}->{'online'} = 1;
$f->{'Greengenes'}->{'version'} = sub {

	%mon2num = qw(
	jan 01  feb 02  mar 03  apr 04  may 05  jun 06
	jul 07  aug 08  sep 09  oct 10 nov 11 dec 12
	);
	
	# example: 09-May-2011
	my $line  = systemc('curl --silent http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/ | grep "current_GREENGENES_gg16S_unaligned.fasta.gz"');

	if ($line eq "") {
		return ""
	}
	
	my ($day, $month_str, $year) = $line =~ /(\d+)\-(\S+)\-(\d\d\d\d)/;
	
	
	unless (defined $year) {
		print STDERR "Error: Could not parse date from line ".$line."\n";
		return "";
	}
	
	my $month = $mon2num{lc($month_str)};
	
	unless (defined $month) {
		print STDERR "Error: Could not map month ".$month_str."\n";
		return "";
	}
	
	return $year.$month.$day;
	
};


$f->{'Greengenes'}->{'download'} = sub {
	my $h = shift(@_);
	my $outdir = $h->{'outdir'};
	my $version = $h->{'version'};
	# from 2011 ?
	systemp(qq[wget -v -N -P $outdir 'http://greengenes.lbl.gov/Download/Sequence_Data/Fasta_data_files/current_GREENGENES_gg16S_unaligned.fasta.gz'])== 0 || return 1;
	# use filedata as version
	systemp(qq[stat -c '%y' current_GREENGENES_gg16S_unaligned.fasta.gz | cut -c 1-4,6,7,9,10 > $outdir/version.txt])== 0 || return 1;
};





my %h = ();

GetOptions (\%h, 'latest=s', 'compare=s');



if (defined $h{'latest'}) {
	
	require Text::TabularDisplay;
	
	open(my $fh, '>', $h{'latest'}) or die "Could not open file '".$h{'latest'}."' $!";


	

	my $table_static = Text::TabularDisplay->new("source", "version");
	my $table_online = Text::TabularDisplay->new("source", "version");

	my $versions={};

	foreach my $s (@sources) {
		my $v = '';
		
		print "+++++ $s ++++++\n";
		if (defined $f->{$s}->{'version'}) {
		
			$v = &{$f->{$s}->{'version'}};
			if ($v eq "") {
				$v = 'ERROR';
			}
			
			
		} else {
			
			$v = 'undef'
		}
		print $fh "$s\t$v\n";

		if (defined $f->{$s}->{'online'} && $f->{$s}->{'online'}==1) {
			$table_online->add( $s, $v );
		} else {
			$table_static->add( $s, $v );
		}
	}
		close($fh);

	print "------------- static\n";

	print $table_static->render."\n";

	print "------------- online \n";

	 print $table_online->render."\n";

	
	print "Version written to file ".$h{'latest'}."\n";
	
}


if (defined $h{'compare'}) {
	require Text::TabularDisplay;
	
	
	my $workdir = getcwd;
	
	my $table_compare = Text::TabularDisplay->new("source", "latest", "in-shock", "on-disk", "existing versions");
	
	my $filename = $h{'compare'};
	
	my $file_versions = {};
	
	open(my $data, '<', $filename) or die "Could not open '$filename' $!\n";
 
	while (my $line = <$data>) {
 		chomp $line;
		
		my ($s, $v) = split(/\s/, $line);
		unless (defined $v) {
			die;
		}
		$file_versions->{$s}->{'latest'}=$v;
	}
	print Dumper($file_versions);
	
	
	print "------------- Compare with Shock \n";

	foreach my $s (@sources) {
		my $v = $file_versions->{$s}->{'latest'};
		
		print "+++++ $s ++++++\n";
		if (defined $v) {
			
			my $nodes_match =  $sc->query('type' => 'data-library', 'project' => 'M5NR', 'data-library-name' => 'M5NR_source_'.$s);
			
			print Dumper($nodes_match);
			$file_versions->{'shock'}->{$s}=0;
			my $version_matches=0;
			my @versions=();
			foreach my $i (@{$nodes_match->{'data'}}) {
				my $attr =$i->{'attributes'};
				my $version=$attr->{'version'};
				
				if (lc($version) eq lc($v)) {
					$file_versions->{'shock'}->{$s}=1;
					$version_matches++;
				}
				
				push(@versions, $version);
			}
			
			my $version_txt = $workdir."/$s/version.txt";
			my $version_txt_value = "";
			if (-e $version_txt) {
				$version_txt_value = `cat $version_txt`;
				chomp($version_txt_value);
			}
			
			
			if ($file_versions->{'shock'}->{$s} == 1) {
				$table_compare->add( $s, $v, "yes" , $version_txt_value, join(' ', @versions));
			} else {
				$table_compare->add( $s, $v, "no" , $version_txt_value, join(' ', @versions) );
			}
			
			
			my $matches  = ($nodes_match->{'total_count'}) || 0;
			
			
			
			
			#print "Found ".$matches." versions in total and ".$version_matches." version in Shock matches the latest version.\n";
			
			
			
			
		}
		
	}

	print $table_compare->render."\n";
	
}



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



