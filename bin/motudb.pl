#!/usr/bin/perl

# motuDB.pl
#  see http://www.bork.embl.de/software/mOTU/
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
  print STDERR "Usage: \tmotudb.pl <filename1> \n";
  print STDERR " \te.g. motudb.pl mOTU.v1.padded	\n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open(my $md52id, '>',    'md52id_motudb.txt') or die ;
open(my $md52seq, '>',   'md52seq_motudb.txt') or die ;
#open(my $md52tax, '>',  'md52tax_motudb.txt') or die ;
#open(my $id2tax, '>',  'id2tax_motudb.txt') or die ;


# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s='';  my $seq='';
while (<$fh1>) {
  
  # for every header line
    if (/>/) {
  
      # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record
       
         $md5s = md5_hex($seq);
         
         # print the output
         print $md52id "$md5s\t$id\n"; 
         print $md52seq "$md5s\t$seq\n";
        #
         # reset the values for the next record
         $id='';  $md5s='';   
       }              


    my $line = $_;
#    $line =~ s/>//g;

      ($id)= ( $line =~ />(.*)\W\d+\W\d+/ );

      $seq = ""; # clear out old sequence
   }         
   else {    
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }         
}  # end of line  



close ($fh1);

