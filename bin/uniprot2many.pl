#!/usr/bin/perl

# uniprot2many --  convert Uniprot flat files into as many MD5nr input files as possible
# no parameters, expects to be run from directory with *.dat files.
# all files created are two colum tables
#
# naming convention md52id_<source>.txt
#
# obtain: uniprot sequence, uniprot function, uniprot taxonomy, EC, CAZy, eggnog, pfam, interpro, go
# 
# the parser is very brute force as bioperl and biopython will not extract all required fields
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::File ;


# the main trick is to read the document record by record
$/='//';

#open my $fh1, '<', 'sprot_short.dat' or die;
#open my $fh1, '<', 'uniprot_sprot.dat' or die;

my $fh1 = new IO::File "<uniprot_sprot.dat.gz"
       or die "Cannot open 'uniprot_sprot.dat.gz': $!\n" ;

open(my $md5uniprot, '>', 'md52id_uni.txt') or die ;
open(my $uni2func, '>', 'id2func_uniprot.txt') or die ;
open(my $md5uni_func, '>', 'md52func_uniprot.txt') or die ;
open(my $md5seq, '>', 'md52seq_uniprot.txt') or die ;
open(my $md5go, '>', 'md52id_go.txt') or die ;
open(my $md5ipr, '>', 'md52id_ipr.txt') or die ;
open(my $md5pfam, '>', 'md52id_pfam.txt') or die ;
open(my $md5kegg, '>', 'md52id_kegg.txt') or die ;
open(my $md5cazy, '>', 'md52id_cazy.txt') or die ;
open(my $md5ec, '>', 'md52id_ec.txt') or die ;
open(my $md5eggnog, '>', 'md52id_eggnog.txt') or die ;
open(my $md5tax, '>', 'md52taxid.txt') or die ;


# ################
while (my $record = <$fh1>) {

my $id; my $go=''; my $kegg=''; my $md5s; my $pfam=''; my $ipr=''; my $func='';
my $cazy=''; my $ec=''; my $eggnog='';my $tax='';

#  print $record."\n\n";

  #unset EOL
  $/='';

  foreach my $line (split /\n/ ,$record) {
    #print $line."\n";

    if ($line =~ /^ID\W+(\w+)/ ) {
	$id=$1;
#	print "ID: $id\n"; 
 	next;
    }


# sprot_short.dat:OH   NCBI_TaxID=58607; Gryllus campestris.
# sprot_short.dat:OH   NCBI_TaxID=7108; Spodoptera frugiperda (Fall armyworm).
# trembl_short.dat:OX   NCBI_TaxID=2261 {ECO:0000313|EMBL:AAC45663.1};
# trembl_short.dat:OX   NCBI_TaxID=183757 {ECO:0000313|EMBL:BAD21116.1};
#

     if  ($line =~ /^OX\W+NCBI_TaxID=(\w+);/) {
             $tax=$1;
        next;
    }

# needs to push ids into an array
  #  if  ($line =~ /^DR\W+CAZy;\W+(\w+);/) {
     if  ($line =~ /^DR\W+CAZy;\W+\w+;(.*)./) {
             $cazy=$1;
      #      print "CAZy: $cazy\n";
        next;
    }

# needs to push ids into an array
    if  ($line =~ /^DR\W+InterPro\W+IPR(\w+)/) {
	$ipr=$1;
#	print "IPR$ipr\n";
        next;
    }

# needs to push ids into an array
    if  ($line =~ /^DR\W+Pfam;\W+PF(\w+)/) {
	$pfam=$1;
	#print "PF$pfam\n";
         next;
    }

   if  ($line =~ /^DE\W+RecName:\W+Full=(.+);/) {
        $func="$1";
        next;
    } 

#DE            EC=3.2.1.1 {ECO:0000313|EMBL:AAC45663.1};
# needs to push ids into an array
    if  ($line =~ /^DE\W+EC=(\w+).(\w+).(\w+).(\w+)\W+/) {
	$ec="$1.$2.$3.$4";
        next;
    }

#trembl_short.dat:DR   eggNOG; arCOG01218; Archaea.
#trembl_short.dat:DR   eggNOG; COG0526; LUCA.
#sprot_short.dat:DR   eggNOG; ENOG410J6YU; Eukaryota.
   if  ($line =~ /^DR\W+eggNOG;\W+(\w+);/) {
	$eggnog="$1";
	print "NOG:$eggnog\n";
        next;
    }

   if  ($line =~ /^DR\W+KEGG;\W+(\w+):(\w+)/) {
	$kegg="$1:$2";
	#print "$kegg\n";
        next;
    }

# needs to push ids into an array
    if  ($line =~ /^DR\W+GO;\W+GO:(\w+)/) {
	$go=$1;
	#print "GO:$go\n";
        next;
    }


# parse sequence, generate md5 and write outfiles 
    if  ($line =~ /^SQ/) {

	my @lines = split ('SQ ', $record);
	#print Dumper(@lines);
        my $sequence = @lines[1];
	$sequence =~ s/^(.*\n)//;
	$sequence =~ tr / \n\/\///ds;
#	print "ID: $id\n";
#	print "SEQ: $sequence\n";
	$md5s = md5_hex($sequence);
	#print "MD5 $md5\n";
	

        print $md5seq "$md5s\t$sequence\n";

        print $md5uniprot "$md5s\t$id\n";

        print $md5uni_func "$md5s\t$func\n";

        print $uni2func "$id\t$func\n";
	
	print $md5tax   "$md5s\t$tax\n";

	if ( $cazy ne "" ) {
	  print $md5cazy "$md5s\t$cazy\n";
	}
	if ( $ec ne "" ) {
	  print $md5ec "$md5s\t$ec\n";
	}

	if ( $eggnog ne "" ) {
        print $md5eggnog "$md5s\t$eggnog\n"; 
	}

	if ( $ipr ne "" ) {
          print $md5ipr "$md5s\t$ipr\n"; 
	}
	if ( $pfam ne "" ) {
          print $md5pfam "$md5s\t$pfam\n";
	}
	if ( $kegg ne "" ) {
          print $md5kegg "$md5s\t$kegg\n";
	}
	if ( $go ne "") {
          print $md5go "$md5s\t$go\n";
	}
	if ( $cazy ne "" ) {
	  print $md5cazy "$md5s\t$cazy\n";
	}
  
	next
    }
      # reset EOL
      $/='//';
  }

}

close ($fh1);

####################################################
####################################################
####################################################
#print "Sprot done, moving on to TREMBL\n";

#open my $fh2, '<', 'uniprot_trembl.dat' or die;
#open my $fh2, '<', 'trembl_short.dat' or die;

my $fh2 = new IO::File "<uuniprot_trembl.dat.gz"
       or die "Cannot open 'uniprot_trembl.dat.gz': $!\n" ;

$/="\n//";  

# now almost the same procedure for trembl
while (my $record = <$fh2>) {

my $id; my $go=''; my $kegg=''; my $md5s; my $pfam=''; my $ipr=''; my $func=''; 
my $cazy=''; my $ec=''; my $eggnog=''; my $tax='';

#  print $record;

  #unset EOL
  $/='';

  foreach my $line (split /\n/ ,$record) {
    #print $line."\n";

    if ($line =~ /^ID\W+(\w+)/ ) {
	$id=$1;
	#print "ID: $id\n"; 
 	next;
    }
    
    if  ($line =~ /^OX\W+NCBI_TaxID=(\w+);/) {
             $tax=$1;
        next;
    }

    if  ($line =~ /^DE\W+\w+Name:\W+Full=(.+);/) {
        $func=$1;
        next;
    }

# needs to push ids into an array
    if  ($line =~ /^DR\W+InterPro\W+IPR(\w+)/) {
	$ipr=$1;
#	print "IPR$ipr\n";
        next;
    }


#    DR   CAZy; GT4; Glycosyltransferase Family 4.
#    DE   SubName: Full=CAZy families CE14 protein {ECO:0000313|EMBL:AIA83773.1};

   # if  ($line =~ /^DR\W+CAZy;\W+(\w+);/) {
    if  ($line =~ /^DR\W+CAZy;\W+(\w+);/) {
        $cazy=$1;
        next;
    }
    if  ($line =~ /^DE\W+SubName:\W+Full=CAZy\W+families\W+(\w+)/) {
         $cazy=$1;
         next;
     }

# needs to push ids into an array
    if  ($line =~ /^DR\W+Pfam;\W+PF(\w+)/) {
	$pfam=$1;
        next;
    }

    if  ($line =~ /^DR\W+KEGG;\W+(\w+):(\w+)/) {
	$kegg="$1:$2";
        next;
    }

#trembl_short.dat:DR   eggNOG; arCOG01218; Archaea.
#trembl_short.dat:DR   eggNOG; COG0526; LUCA.
#sprot_short.dat:DR   eggNOG; ENOG410J6YU; Eukaryota.
   if  ($line =~ /^DR\W+eggNOG;\W+(\w+);/) {
	$eggnog="$1";
        next;
    }

#DE            EC=3.2.1.1 {ECO:0000313|EMBL:AAC45663.1};
# needs to push ids into an array
    if  ($line =~ /^DE\W+EC=(\w+).(\w+).(\w+).(\w+)\W+/) {
	$ec="$1.$2.$3.$4";
        next;
    }

  # needs to push ids into an array
    if  ($line =~ /^DR\W+GO;\W+GO:(\w+)/) {
	$go=$1;
	#print "GO:$go\n";
        next;
    }

  # parse sequence, generate md5 and write outfiles 
  if  ($line =~ /^SQ/) {

	my @lines = split ('SQ ', $record);
  #	print Dumper(@lines);
  # split the record at the correct position to catch the sequences
  my $sequence = @lines[1];
  # join lines, remove the first list as well as the record separator 
	$sequence =~ s/^(.*\n)//;
	$sequence =~ tr / \n\/\///ds;
	
#	print "SEQ: $sequence\n";
	#print $sequence."\n\n\n";

	$md5s = md5_hex($sequence);
	#print "MD5 $md5\n";

        print $md5seq "$md5s\t$sequence\n";

	if ( $id ne "") {
          print $md5uniprot "$md5s\t$id\n";
	}
	else  { print "Can't find ID for $md5s \t$id\n"; die ;}

        print $md5uni_func "$md5s\t$func\n";
	print $md5tax "$md5s\t$tax\n";

	if ( $ipr ne "" ) {
        print $md5ipr "$md5s\t$ipr\n"; 
	}

	if ( $eggnog ne "" ) {
        print $md5eggnog "$md5s\t$eggnog\n"; 
	}

	if ( $pfam ne "" ) {
        print $md5pfam "$md5s\t$pfam\n";
	}
	if ( $kegg ne "" ) {
        print $md5kegg "$md5s\t$kegg\n";
	}
	if ( $go ne "") {
        print $md5go "$md5s\t$go\n";
	}

	if ( $cazy ne "" ) {
	  print $md5cazy "$md5s\t$cazy\n";
	}
	if ( $ec ne "" ) {
	  print $md5ec "$md5s\t$ec\n";
	}

	# skip to next record
	next
      } # end of SQ case
	
      # reset EOL
      $/="\n//";
  }

} # while fh2



# be nice and close file handles
close($fh2);
close ($md5uniprot);
close($md5go);
close($md5ipr);
close($md5pfam);
close($md5kegg);
close($md5uniprot);
close($md5seq);
