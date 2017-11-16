#!/usr/bin/perl

# greengenes
# 
# extract md52id, md52seq, id2tax
#

#
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record

my $filename=shift @ARGV;

if ( $filename eq "" )
{
  print STDERR "Usage: \tgreengenes.pl <filename1> \n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open(my $md52id, '>',    'md52id_greengenes.txt') or die ;
open(my $md52seq, '>',   'md52seq_greengenes.txt') or die ;
open(my $id2tax, '>',   'id2tax_greengenes.txt') or die ;


# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $tax='';   my $seq='';
while (<$fh1>) {
  
  # for every header line
    if (/>/) {
  
      # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record
       
         $md5s = md5_hex($seq);
         
         # print the output
         print $md52id "$md5s\t$id\n";
         print $md52seq "$md5s\t$seq\n";
         print $id2tax "$id\t$tax\n";

         # reset the values for the next record
         $id='';  $md5s='';  $tax='';
       }              


#  >14 AF068820.2 hydrothermal vent clone VC2.1 Arc13 k__Archaea; p__Euryarchaeota; c__Thermoplasmata; o__Thermoplasmatales; f__Aciduliprofundaceae; otu_204

    my $line = $_;
#    $line =~ s/>//g;
    
      my @words = split ( / /, $line)  ;  
      $id = substr(@words[0],1);
      
   #   print "ID\t$id\n";
      ($tax) = ($line =~ />\d+\W+\w+.\d+\W+(.*)/);
  #    print "TAX\t$tax\n";      
  
      $seq = ""; # clear out old sequence
   }         
   else {    
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }         
}  # end of line  



close ($fh1);

