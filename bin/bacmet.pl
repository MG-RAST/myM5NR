#!/usr/bin/perl

# bacmet
#
# two classes of genes
# PRE = predicted resistance  // BacMet_PRE.40556.fasta
# EXP = experimentally verified resistance // BacMet_EXP.704.fasta
# header format:
# >BAC0621|copA|tr|F4ZBX3|F4ZBX3_XANCI CopA OS=Xanthomonas citri subsp. citri GN=copA PE=4 SV=1
#
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record

my $filename=shift @ARGV;
my $filename_pre=shift @ARGV;

if ( $filename eq "" or $filename_pre eq "" )
{
  print STDERR "Usage: \tbacmet.pl <filename1> <filename2>\n";
  print STDERR " \te.g. bacmet.pl BacMet_EXP.704.fasta BacMet_Predicted.40556.fasta\n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

my $fh2 = new IO::Uncompress::Gunzip ("$filename_pre")
              or die "Cannot open '$filename': $!\n" ;


open(my $md52id, '>',    'md52id.txt') or die ;
open(my $md52func, '>',  'md52func.txt') or die ;
open(my $md52seq, '>',   'md52seq.txt') or die ;
open(my $id2func, '>',   'id2func.txt') or die ;


# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $func=''; my $subsys=''; my $taxid=''; my $taxname=''; my $seq='';
while (<$fh1>) {

  # for every header line
    if (/>/) {


      # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record
         chomp $seq;
         $seq=lc($seq);
         $md5s = md5_hex($seq);

         # print the output
         print $md52id "$md5s\t$id\n";
         print $md52seq "$md5s\t$seq\n";
         print $md52func "$md5s\t$func\n";
         print $id2func "$id\t$func\n";

         # reset the values for the next record
         $id='';  $md5s='';  $func='';  $subsys='';  $taxid='';  $taxname='';
       }


#>BAC0002|abeS|tr|Q2FD83|Q2FD83_ACIBA QacEdelta1 SMR family efflux pump OS=Acinetobacter baumannii GN=qacEdelta1 PE=3 SV=1
my $line = $_;
  $line =~ s/>//g;
  $line =~ s/\]//g;

      my @header = split ('\|', $line);
      $id=@header[0];
#      print "ID:$id\n";
      $id =~ s/>//g;

      my $pos=index($line,' '); # find first space in string
      ( $func ) = substr($line, $pos);
      ($func) = ($func =~ /(.+)\W+OS=.+/);

      $seq = ""; # clear out old sequence
   }
   else {
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }
}  # end of line



close ($fh1);


# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $func=''; my $subsys=''; my $taxid=''; my $taxname=''; my $seq='';
while (<$fh2>) {

  # for every header line
    if (/>/) {
        # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record

         $md5s = md5_hex($seq);

         # print the output
         print $md52id "$md5s\t$id\n";
         print $md52seq "$md5s\t$seq\n";
         print $md52func "$md5s\t$func\n";
         print $id2func "$id\t$func\n";

         # reset the values for the next record
         $id='';  $md5s='';  $func='';  $subsys='';  $taxid='';  $taxname='';
       }

#>BAC0002|abeS|tr|Q2FD83|Q2FD83_ACIBA QacEdelta1 SMR family efflux pump OS=Acinetobacter baumannii GN=qacEdelta1 PE=3 SV=1
my $line = $_;
  $line =~ s/>//g;
  $line =~ s/\]//g;

      my @header = split ('\|', $line);
      $id=@header[1];
#      print "ID:$id\n";
      $id =~ s/>//g;

      my $pos=index($line,' '); # find first space in string
      ( $func ) = substr($line, $pos);
      $pos=index($func,'[');
      #print "POS:\t$pos\n";
      $func = substr($func, 0,$pos);

      #print "FUNC:\t $func\n";

      $seq = ""; # clear out old sequence
   }
   else {
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }
}  # end of line



close ($fh2);

# remove obsolete files from Parsed DIR
unlink ("BacMet*");
