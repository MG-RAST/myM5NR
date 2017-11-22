#!/usr/bin/perl

# generic genbank parser
#
# extract seq, func, tax, id
# the parser is very brute force as bioperl and biopython will not extract all required fields
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

my $filename1=shift @ARGV;
my $filename2=shift @ARGV;
my $filename3=shift @ARGV;

if ( $filename1 eq "" || $filename2 eq "" || $filename3 eq "")
{
  print STDERR "Usage: \tgenbank.pl <filename1> <filename2> <filename3>\n";
  exit 1;
}


open(my $md52id, '>',    'md52id.txt') or die ;
open(my $md52seq, '>',   'md52rnaseq.txt') or die ;
open(my $md52tax, '>',  'md52tax.txt') or die ;


read_file($filename1);
read_file($filename2);
read_file($filename3);

sub read_file {

      my $filename = shift(@_);

      my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

      $/="\n//";

      # now almost the same procedure for trembl
      while (my $record = <$fh1>) {

          my $id=''; my $md5s; my $func=''; my $tax='';
            #unset EOL
            $/='';

            foreach my $line (split /\n/ ,$record) {
            # LOCUS       S000494589               454 bp    rRNA    linear   BCT 15-Jun-2007
              if ($line =~ /^LOCUS\s+(\w+)\W+.*/ ) {
                $id=$1; next }
              #             /db_xref="taxon:77133"
              if  ($line =~ /^\W+\/db_xref="taxon:(\w+)"/) {
                       $tax=$1; next;}
            # parse sequence, generate md5 and write outfiles
            if  ($line =~ /^ORIGIN/) {
          	my @lines = split ('ORIGIN', $record);
              # split the record at the correct position to catch the sequences
              my $sequence = @lines[1];
              # join lines, remove the first list as well as the record separator
          	$sequence =~ s/^(.*\n)//;
          	$sequence =~ tr /[0-9] \n\///ds;

          	$md5s = md5_hex($sequence);
          	#print "MD5 $md5\n";

            die "cannot find ID\n" if ( $id eq "");

            print $md52seq "$md5s\t$sequence\n";
          	print $md52tax "$md5s\t$tax\n";
            print $md52id "$md5s\t$id\n" ;
          	# skip to next record
          	next
            } # end of SQ case
          }
                # reset EOL
                $/="\n//";

      }
}

exit 0;
