#!/usr/bin/perl

# goslim.pl --   convert goslim download to M5nr usable format
# parameter is just the filename
#
#
#
# the parser is very brute force as bioperl, etc will not extract all required fields
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

use Getopt::Long;


my $Swiss_prot_file;
my $TrEmble_file;
my $verbose;

my $filename=shift @ARGV;

if ( $filename eq "" )
{
  print STDERR "Usage: \tgoslim.pl <filename1> \n";
  print STDERR " \te.g. goslim.pl goslim_metagenomics.obo\n";
  exit 1;
}

    # the main trick is to read the document record by record
    #
    # [Term]
    # id: GO:0000015

    $/="\n\n";

    open my $fh1, '<', $filename or die;
    #open my $fh1, '<', 'uniprot_sprot.dat' or die;
    open(my $id2hier, '>',    'id2hierachy.txt') or die ;

    my $id=""; my $name=""; my $namespace=""; my $hier1='';

    # ################
    while (my $record = <$fh1>) {
      $id=""; $name=""; $namespace=""; my $hier1='';

   # ignore all non Term entries
   next if ($record !~ /\[Term\].*/ ) ;

   # now handle the record
   $/='';

    foreach my $line (split /\n/ ,$record) {
      #  print "LINE: $line\n";

        if ($line =~ /^id.\W+GO:(\d+)/ ) {
          $id = $1;
          next;
        }
        if ($line =~ /^name.\W+(.*)/ ) {
          $name = $1;
          next;
        }
        if ($line =~ /^namespace.\W+(\w+)/) {
          $namespace=$1;
        }
        if ($line =~ /^is_a:\W+GO:\d+\W+!\W+(.*)/ ) {
          $hier1 = $1;

      #      print "END\t\tGO:$id\t$name\t$namespace\n";
            print $id2hier "GO:$id\t$name\t$hier1\t$namespace\n";
            next;
          } # if namespace

    } # foreach $line

    # print values to file here

            # set OLD again
        $/="\n\n";

  } # while $record

    # handle last record (before EOF)

    exit 0;
