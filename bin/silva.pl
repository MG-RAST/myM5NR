#!/usr/bin/perl

# SILVA
#
# extract md52seq_eggnog, id2tax, md52taxstring_silva
#
# >GAXI01000526.151.1950 Eukaryota;Opisthokonta;Holozoa;Metazoa (Animalia);Eumetazoa;Bilateria;Arthropoda;Hexapoda;Ellipura;Collembola;Tetrodontophora bielanensis (giant springtail)
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
  print STDERR "Usage: \tsilva.pl <filename1> \n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open(my $md52id, '>',    'md52id.txt') or die ;
open(my $md52seq, '>',   'md52rnaseq.txt') or die ;
open(my $md52tax, '>',  'md52tax.txt') or die ;
open(my $id2tax, '>',  'id2tax.txt') or die ;


# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $tax='';  my $seq='';
while (<$fh1>) {

  # for every header line
    if (/>/) {

      # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record

         chomp $seq;
         $seq = lc($seq);
         $md5s = md5_hex($seq);

         # print the output
         print $md52id "$md5s\t$id\n";
         print $md52seq "$md5s\t$seq\n";
         print $id2tax "$id\t$tax\n";
         print $md52tax "$md5s\t$tax\n";

         # reset the values for the next record
         $id='';  $md5s='';  $tax='';
       }


#   header: >515620.EUBELI_00005
    my $line = $_;
#    $line =~ s/>//g;

#>GAXI01000526.151.1950 Eukaryota;Opisthokonta;Holozoa;Metazoa (Animalia);Eumetazoa;Bilateria;Arthropoda;Hexapoda;Ellipura;Collembola;Tetrodontophora bielanensis (giant springtail)
        $id = (split (/ /, $line))[0];
        my $len=length($id);
        $id = substr ($id,1);  # remove > char
        $tax= substr($line,$len+1);
        chomp $tax;

      #($id, $tax) = ( $line =~ />(\w+).(.+)/ );

      #print "ID:\t$id\n";
     #print "TAX:\t$tax\n";

      $seq = ""; # clear out old sequence
   }
   else {
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }
}  # end of line


# print last record
$md5s = md5_hex($seq);

# print the output
print $md52id "$md5s\t$id\n";
print $md52seq "$md5s\t$seq\n";
print $id2tax "$id\t$tax\n";
print $md52tax "$md5s\t$tax\n";


close ($fh1);
