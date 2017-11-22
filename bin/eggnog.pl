#!/usr/bin/perl

# eggnog
#
# extract md52id, md52seq. md52func, id2func, md52tax, id2tax
# header format:
# >515620.EUBELI_00003
#>515620.EUBELI_00004
#>515620.EUBELI_00005

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
  print STDERR "Usage: \teggnog.pl <filename1> \n";
  print STDERR " \te.g. bacmet.pl eggnog4.proteins.core_periphery.fa.gz\n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open(my $md52id, '>',    'md52id_eggnog.txt') or die ;
open(my $md52seq, '>',   'md52seq_eggnog.txt') or die ;
open(my $md52tax, '>',  'md52tax_eggnog.txt') or die ;
open(my $id2tax, '>',  'id2tax_eggnog.txt') or die ;


# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $func='';  my $tax='';  my $seq='';
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
      #   print $md52func "$md5s\t$func\n";
        # print $id2func "$id\t$func\n";
         print $id2tax "$id\t$tax\n";
         print $md52tax "$md5s\t$tax\n";

         # reset the values for the next record
         $id='';  $md5s='';  $func='';  $tax='';
       }


#   header: >515620.EUBELI_00005
    my $line = $_;
#    $line =~ s/>//g;

      ($tax,$id) = ( $line =~ />(\w+).(.+)/ );

 #     print "ID:\t$id\n";
 #    print "TAX:\t$tax\n";

      $seq = ""; # clear out old sequence
   }
   else {
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }
}  # end of line



close ($fh1);
