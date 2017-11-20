#!/usr/bin/perl

# subsystems
#
# extract md52id, md52seq. md52id, md52subsystems, id2subsystems
#
#47326e4716f40d23d3d5a899ca6ef11e        fig|340185.3.peg.4788   Zinc resistance-associated protein              Subsystems      Virulence       Resistance to antibiotics
#and toxic compounds   Zinc resistance Zinc resistance-associated protein      MSKNDSLPAAGESFLLVYHARLPVISAFHRWHGRCNTRSKTTTGGLTMKRNTKIALVMMALSAMAMGSTSAFAHGGHGMWQQNAAPLTSEQQ
#TAWQKIHNDFYAQSSALQQQLVTKRYEYNALLAANPPDSSKINAVAKEMENLRQSLDELRVKRDIAMAEAGIPRGTGMGMGYGGCGGGGHMGMGHW


#
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record

my $dirname=shift @ARGV;

if ( $dirname eq "" )
{
  print STDERR "Usage: \tsubsystems.pl <DIRNAME>\n";
  exit 1;
}


open(my $md52id, '>',    'md52id_subsystems.txt') or die ;
open(my $md52seq, '>',   'md52seq_subsystems.txt') or die ;
open(my $md52func, '>',   'md52func_subsystems.txt') or die ;
open(my $md52hierarchy, '>',   'md52hierarchy_subsystems.txt') or die ;
open(my $id2hierarchy, '>',   'id52hierarchy_subsystems.txt') or die ;
open(my $id2func, '>' ,'id2func_subsystems.txt') or die ;

# FOR EACH FILE IN THE DIRECTORY
opendir(my $dirh, $dirname) or die "Could not open $dirname\n";

while (defined (my $filename = readdir($dirh)) ) {

  next if $filename !~ /subsystems_.*/ ;
  # print "WORKING ON: $filename\n";

  open (my $fh1, '<', "$dirname/$filename") or die "Cannot open $dirname/$filename: $!\n" ;

      # ################# ################# ################# ################
      # ################# ################# ################# ################
      # ################# ################# ################# ################
  my $header=''; my $id; my $md5=''; my $func='';  my $seq=''; my $subsystem1; my $subsystem2; my $subsystem3;

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
      $subsystem1= @words[5];
      $subsystem2= @words[6];
      $subsystem3= @words[7];

      if ($subsystem2 eq ''){
        $subsystem2 = '-';
      }

      chomp $seq;
      #print "ID\t$id\n";
      #print "MD5\t$md5\n";
      #print "SEQ\t$seq\n";
      #print "FUNC:\t$func\n";
      #print "Subsystems: [1] $subsystem1\t[2] $subsystem2 \t[3] $subsystem3 \n";

      chomp $func;
      # if we already have a sequence ...  ## need to take care of last record
      my $md52 = md5_hex($seq);
      die "$filename::$id\t\$md5\n"if ($md52 != $md5); # a safety precaution since SEED is important

      # print the output
      print $md52id "$md5\t$id\n";
      print $md52seq "$md5\t$seq\n";
      print $md52func "$md5\t$func\n";
      print $id2func "$id\t$func\n";
      print $md52hierarchy "$md5\t$subsystem1\t$subsystem2\t$subsystem3\n";
      print $id2hierarchy "$id\t$subsystem1\t$subsystem2\t$subsystem3\n";

   # reset the values for the next record
   $id='';  $md5='';  $func=''; $subsystem1='';$subsystem2=''; $subsystem3='';

  } # while <$fh1>
    close ($fh1);


} # of while readdir

closedir($dirh);
