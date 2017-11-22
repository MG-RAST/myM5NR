#!/usr/bin/perl

# card
#
# extract md52id, md52seq. md52func, id2func, md52tax, id2tax
# header format:
# >gb|AFJ59957.1|ARO:3001989|CTX-M-130 [Escherichia coli]
# >gb|AEX08599.1|ARO:3002356|NDM-6 [Escherichia coli]
# >gb|BAP68758.1|ARO:3001855|ACT-35 [Enterobacter cloacae]
# >gb|AAF61417.1|ARO:3002244|CARB-5 [Acinetobacter calcoaceticus subsp. anitratus]
# >gb|AAP74657.1|ARO:3000600|Erm(34) [Bacillus clausii]

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
  print STDERR "Usage: \tcard.pl <filename1> \n";
  print STDERR " \te.g. card.pl card.fasta\n";
  print STDERR " requires ncbi_taxomony.csv in same directory";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open (my $ncbitax, '<', 'ncbi_taxomony.csv' ) or die "cannot open ncbi_taxomony.csv";

open(my $md52id,  '>', 'md52id.txt') or die ;
open(my $md52hier,'>', 'md52hier.txt' ) or die ;
open(my $id2hier, '>', 'id2hier.txt' ) or die ;
open(my $md52seq, '>', 'md52seq.txt') or die ;
open(my $md52tax, '>', 'md52tax.txt') or die ;
open(my $md52func,'>', 'md52func.txt') or die ;

## generate a hash with NCBI taxnomy string to ID mapping
#
my %ncbihash=''; my $id; my $taxstring; my $junk;
while ( my $line = <$ncbitax>) {
  $id=''; $taxstring='';
  ($id, $taxstring,$junk) = (split /,/ , $line);
  $taxstring =~ s/"//g;
  $ncbihash{$taxstring}=$id;
}

# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $func='';  my $tax='';  my $seq=''; my $card='';
while (<$fh1>) {

  # for every header line
    if (/>/) {

      # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record

         $md5s = md5_hex($seq);

         # print the output
         print $md52id "$md5s\t$id\n";
         print $md52seq "$md5s\t$seq\n";
         print $md52func "$md5s\t$func\n";
         print $md52hier "$md5s\t$card\n";
         print $id2hier "$id\t$card\n";
         print $md52tax "$md5s\t$ncbihash{$tax}\n";  # convert via CARD provided translation table

         # reset the values for the next record
         $id='';  $md5s='';  $func='';  $tax='';
       }


    my $line = $_;
#    $line =~ s/>//g;
# >gb|AFJ59957.1|ARO:3001989|CTX-M-130 [Escherichia coli]
# >gb|AEX08599.1|ARO:3002356|NDM-6 [Escherichia coli]
# >gb|BAP68758.1|ARO:3001855|ACT-35 [Enterobacter cloacae]
# >gb|AAF61417.1|ARO:3002244|CARB-5 [Acinetobacter calcoaceticus subsp. anitratus]
# >gb|AAP74657.1|ARO:3000600|Erm(34) [Bacillus clausii]

    my @fields='';

    @fields = (split '\|', $line);
    $card= $fields[2];
    $id=$fields[1];
    my @rest = split ( / / , $fields[3]);
    $func= shift @rest;
    $tax = (join ' ', @rest);
    $tax =~ s/\n//g;
    $tax =~ s/\[//g;
    $tax =~ s/\]//g;

#    $id = $rest[0];


    #  ($rest, $card, $id, $rest2) = (split '\|', $line);
    #  @fields = split ( /\[/ , $func);
    #  $func = $fields[0];
    #  $tax = $fields[1-3];


      #( $line =~ />gb|.*|ARO:(\d+)|(\w+)\W+\[\(.*\)]%/);



      $seq = ""; # clear out old sequence
   }
   else {
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }
}  # end of line

# print the output

print $md52id "$md5s\t$id\n";
print $md52seq "$md5s\t$seq\n";
print $md52func "$md5s\t$func\n";
print $md52hier "$md5s\t$card\n";
print $id2hier "$id\t$card\n";
print $md52tax "$md5s\t$ncbihash{$tax}\n";  # convert via CARD provided translation table


close ($fh1);
