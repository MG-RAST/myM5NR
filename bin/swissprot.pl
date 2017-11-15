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
use IO::Uncompress::Gunzip;

my $filename=shift @ARGV;

if ( $filename eq "" )
{
  print STDERR "Usage: \tswissprot.pl <filename1> \n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

    # the main trick is to read the document record by record
$/='//\n';

open(my $md52id, '>',    'md52id_swissprot.txt') or die ;
open(my $md52seq, '>',   'md52seq_swissprot.txt') or die ;
open(my $md52id_go, '>', 'md52id_go_swissprot.txt') or die ;
open(my $md52id_ipr, '>', 'md52id_ipr_swissprot.txt') or die ;
#open(my $md52tax, '>',  'md52tax_motudb.txt') or die ;
#open(my $id2tax, '>',  'id2tax_motudb.txt') or die ;
open(my $md52uni_func, '>', 'md52func_swissprot.txt') or die ;
open(my $md52id_pfam, '>', 'md52id_pfam_swissprot.txt') or die ;
open(my $md52id_kegg, '>', 'md52id_kegg_swissprot.txt') or die ;
open(my $md52id_cazy, '>', 'md52id_cazy_swissprot.txt') or die ;
open(my $md52id_ec, '>', 'md52id_ec_swissprot.txt') or die ;
open(my $md52id_eggnog, '>', 'md52id_eggnog_swissprot.txt') or die ;
open(my $md52id_cog, '>', 'md52id_cog_swissprot.txt') or die ;
open(my $md52tax, '>', 'md52taxid.txt') or die ;


# ################
while (my $record = <$fh1>) {

  my $id; my $go=''; my $kegg=''; my $md5s; my $pfam=''; my $ipr=''; my $func='';
  my $cazy=''; my $ec=''; my $eggnog='';my $tax=''; my $cog='';

  #  print $record."\n\n";

  #unset EOL
  $/='';

  foreach my $line (split /\n/ ,$record)  {
      #print $line."\n";

      if ($line =~ /^ID\W+(\w+)\W+.+/ ) {
          $id=$1;  next;
      }

      if  ($line =~ /^OX\W+NCBI_TaxID=(\w+);/) {
        $tax=$1; next;
      }

      # needs to push ids into an array
      #  if  ($line =~ /^DR\W+CAZy;\W+(\w+);/) {
      if  ($line =~ /^DR\W+CAZy;\W+\w+;(.*)./) {
            $cazy=$1; next;
          }

      # needs to push ids into an array
      if  ($line =~ /^DR\W+InterPro\W+IPR(\w+)/) {
          $ipr=$1; next;
      }

      # needs to push ids into an array
      if  ($line =~ /^DR\W+Pfam;\W+PF(\w+)/) {
          $pfam=$1; next;
      }

      if  ($line =~ /^DE\W+RecName:\W+Full=(.+);/) {
            $func="$1"; next;
      } 

    #DE            EC=3.2.1.1 {ECO:0000313|EMBL:AAC45663.1};
    # needs to push ids into an array
      if  ($line =~ /^DE\W+EC=(\w+).(\w+).(\w+).(\w+)\W+/) {
            $ec="$1.$2.$3.$4";  next;
      }

    #trembl_short.dat:DR   eggNOG; arCOG01218; Archaea.
    #trembl_short.dat:DR   eggNOG; COG0526; LUCA.
    #sprot_short.dat:DR   eggNOG; ENOG410J6YU; Eukaryota.
      if  ($line =~ /^DR\W+eggNOG;\W+(\w+);/) {
           $eggnog="$1"; next;
      }

      if  ($line =~ /^DR\W+KEGG;\W+(\w+):(\w+)/) {
           $kegg="$1:$2"; next;
      }

    # needs to push ids into an array
      if  ($line =~ /^DR\W+GO;\W+GO:(\w+)/) {
        $go=$1;  next;
      }

    # parse sequence, generate md5 and write outfiles 
      if  ($line =~ /^SQ/) {

        	my @lines = split ('SQ ', $record);
        	#print Dumper(@lines);
            # split the record at the correct position to catch the sequences
            my $sequence = @lines[1];
            # join lines, remove the first list as well as the record separator
        	$sequence =~ s/^(.*\n)//;
        	$sequence =~ tr / \n\/\///ds;
        #	print "ID: $id\n";
        #	print "SEQ: $sequence\n";
        	$md5s = md5_hex($sequence);
        	#print "MD5 $md5\n";

          print $md52seq "$md5s\t$sequence\n";
          print $md52uni_func "$md5s\t$func\n";
        	print $md52tax "$md5s\t$tax\n";
  
          if ( $id eq "") { print $record."\n" ;          die "cannot find ID\n" }

          print $md52id "$md5s\t$id\n" ;    	        
          print $md52id_ipr "$md5s\t$ipr\n"    	    if ( $ipr ne "" ); 
          print $md52id_cog "$md5s\t$cog\n"         if ( $cog ne "" ); 
          print $md52id_eggnog "$md5s\t$eggnog\n"   if ( $eggnog ne "" ); 
          print $md52id_pfam "$md5s\t$pfam\n"       if ( $pfam ne "");
          print $md52id_kegg "$md5s\t$kegg\n"     	if ( $kegg ne "" ) ;
          print $md52id_go "$md5s\t$go\n"     	    if ( $go ne "");
          print $md52id_cazy "$md5s\t$cazy\n"  	    if ( $cazy ne "" );
          print $md52id_ec "$md5s\t$ec\n"     	    if ( $ec ne "" );

        	next;
        } # of if ($line =~ /^SQ/) 

          # reset EOL
          $/='//\n';
      } # foreach
      
} # while read

  