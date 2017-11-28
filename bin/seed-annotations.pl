#!/usr/bin/perl

# seed annotations
#
# extract md52id, md52seq. md52id, id2func
#
#a6e173167c03943a8709615b16285845        fig|470865.2.peg.20     Phage protein   44AHJD-like phages Staphylococcus phage SAP-2   SEED    MTEFEEIVKPDDKEPTEEPTEEPTEEPTEDKTVETIEEENKNKLEP..
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
  print STDERR "Usage: \tseed-annotations.pl <filename>\n";
  exit 1;
}


open(my $md52id, '>',    'md52id.txt') or die ;
open(my $md52seq, '>',   'md52seq.txt') or die ;
open(my $md52func, '>',   'md52func.txt') or die ;
open(my $id2func, '>' ,'id2func.txt') or die ;

# FOR EACH FILE IN THE DIRECTORY
open (my $fh1, '<', "$filename") or die "Cannot open $filename: $!\n" ;

      # ################# ################# ################# ################
      # ################# ################# ################# ################
      # ################# ################# ################# ################
my $header=''; my $id; my $md5=''; my $func='';  my $seq='';

  while (my $line=<$fh1>) {

    # for every header line
    #print "LINE:\t$line\n";

      #    $line =~ s/>//g;
      my @words = split ( /\t/, $line)  ;
      $md5 = @words[0];
      $id = @words[1];
      my $len=scalar @words;
      $seq = @words[$len-1];
      $func= @words[2];

      chomp $seq;
      #print "ID\t$id\n";
      #print "MD5\t$md5\n";
      #print "SEQ\t$seq\n";
      #print "FUNC:\t$func\n";
      #print "Subsystems: [1] $subsystem1\t[2] $subsystem2 \t[3] $subsystem3 \n";

      chomp $func;
      # if we already have a sequence ...  ## need to take care of last record

      # print the output
      print $md52id "$md5\t$id\n";
      print $md52seq "$md5\t$seq\n";
      print $md52func "$md5\t$func\n";
      print $id2func "$id\t$func\n";

   # reset the values for the next record
   $id='';  $md5='';  $func='';

  } # while <$fh1>
    close ($fh1);
