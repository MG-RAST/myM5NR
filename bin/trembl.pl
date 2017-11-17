#!/usr/bin/perl

# trempl --  convert trembl flat files into as many MD5nr input files as possible
# no parameters, expects to be run from directory with *.dat files.
# all files created are two colum tables
#
# naming convention md52id_<source>.txt
#                   id2func_<source>.txt
#                   id2hierarchy_<source>.txt
#
# obtain: trembl sequence, trembl function, trembl taxonomy, EC, CAZy, eggnog, pfam, interpro, go
#
# the parser is very brute force as bioperl and biopython will not extract all required fields
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

my $filename=shift @ARGV;

if ( $filename eq "" )
{
  print STDERR "Usage: \ttrembl.pl <filename1> \n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open(my $md52id, '>',    'md52id_trembl.txt') or die ;
open(my $md52seq, '>',   'md52seq_trembl.txt') or die ;
open(my $id2func, '>',   'id2func_trembl.txt') or die ;
open(my $md52id_go, '>', 'md52id_go_trembl.txt') or die ;
open(my $md52id_ipr, '>', 'md52id_ipr_trembl.txt') or die ;
#open(my $md52tax, '>',  'md52tax_motudb.txt') or die ;
#open(my $id2tax, '>',  'id2tax_motudb.txt') or die ;
open(my $md52uni_func, '>', 'md52func_trembl.txt') or die ;
open(my $md52id_pfam, '>', 'md52id_pfam_trembl.txt') or die ;
open(my $md52id_kegg, '>', 'md52id_kegg_trembl.txt') or die ;
open(my $md52id_cazy, '>', 'md52id_cazy_trembl.txt') or die ;
open(my $md52id_ec, '>', 'md52id_ec_trembl.txt') or die ;
open(my $md52id_eggnog, '>', 'md52id-eggnog_trembl.txt') or die ;
open(my $md52id_cog, '>', 'md52id_cog_trembl.txt') or die ;
open(my $md52tax, '>', 'md52taxid.txt') or die ;



$/="\n//";

# now almost the same procedure for trembl
while (my $record = <$fh1>) {

    my $id; my $go=''; my $kegg=''; my $md5s; my $pfam=''; my $ipr=''; my $func='';
    my $cazy=''; my $ec=''; my $eggnog=''; my $tax=''; my $cog='';

    #  print $record;

      #unset EOL
      $/='';

      foreach my $line (split /\n/ ,$record) {
    #   print $line."\n";

        if ($line =~ /^ID\W+(\w+)/ ) {
          $id=$1;       next;
        }

        if  ($line =~ /^OX\W+NCBI_TaxID=(\w+)\W+/) {
                 $tax=$1; next;
        }

        if  ($line =~ /^DE\W+\w+Name:\W+Full=(.+);/) {
            $func=$1; next;
        }

    # needs to push ids into an array
        if  ($line =~ /^DR\W+InterPro\W+IPR(\w+)/) {
            $ipr=$1;    next;
        }


    #    DR   CAZy; GT4; Glycosyltransferase Family 4.
    #    DE   SubName: Full=CAZy families CE14 protein {ECO:0000313|EMBL:AIA83773.1};

       # if  ($line =~ /^DR\W+CAZy;\W+(\w+);/) {
        if  ($line =~ /^DR\W+CAZy;\W+(\w+);/) {
            $cazy=$1;  next;
        }
        if  ($line =~ /^DE\W+SubName:\W+Full=CAZy\W+families\W+(\w+)/) {
             $cazy=$1; next;
         }

    # needs to push ids into an array
        if  ($line =~ /^DR\W+Pfam;\W+PF(\w+)/) {
            $pfam=$1;  next;
        }

        if  ($line =~ /^DR\W+KEGG;\W+(\w+):(\w+)/) {
            $kegg="$1:$2";   next;
        }

        # catch COG first
        #trembl_short.dat:DR   eggNOG; COG0526; LUCA.
        # remaining eggnog will be collected next
        if  ($line =~ /^DR\W+eggNOG;\W+COG(\d+);\W+LUCA./) {
          $cog="COG$1";  next;
         }

    if  ($line =~ /^DR\W+eggNOG;\W+(\w+);/) {
         $eggnog="$1"; next;
    }
    #sprot_short.dat:DR   eggNOG; ENOG410J6YU; Eukaryota.
       if  ($line =~ /^DR\W+eggNOG;\W+(\w+);/) {
         if ( $eggnog ne '' ) {
           $eggnog = "$eggnog,$1"
           }
         else { $eggnog="$1";
              }
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

      print $md52seq "$md5s\t$sequence\n";
      print $md52uni_func "$md5s\t$func\n";
    	print $md52tax "$md5s\t$tax\n";

      die "cannot find ID\n" if ( $id eq "");

      print $md52id "$md5s\t$id\n" ;
      print $md52id_ipr "$md5s\t$ipr\n"    	    if ( $ipr ne "" );
      print $md52id_cog "$md5s\t$cog\n"         if ( $cog ne "" );
      print $md52id_eggnog "$md5s\t$eggnog\n"   if ( $eggnog ne "" );
      print $md52id_pfam "$md5s\t$pfam\n"       if ( $pfam ne "");
      print $md52id_kegg "$md5s\t$kegg\n"     	if ( $kegg ne "" ) ;
      print $md52id_go "$md5s\t$go\n"     	    if ( $go ne "");
      print $md52id_cazy "$md5s\t$cazy\n"  	    if ( $cazy ne "" );
      print $md52id_ec "$md5s\t$ec\n"     	    if ( $ec ne "" );
      print $md52tax "$md5s\t$tax\n"     	      if ( $tax ne "" );
    	# skip to next record
    	next
      } # end of SQ case
    }
          # reset EOL
          $/="\n//";

}

exit 0;
