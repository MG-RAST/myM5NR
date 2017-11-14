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
    open(my $md52id, '>',    'md52id_go.txt') or die ;


    # ################
    while (my $record = <$fh1>) {
      
      my $id=""; my $name=""; my $namespace="";
   #  print "$record\n";
      
     if ( $record =~ /\[Term\].*/ ) {

        # now handle the record
        $/='';    
    
        foreach my $line (split /\n/ ,$record) {
          #print "LINE: $line\n";
          ($id) = $line =~ /^id.\W+GO:(\d+)/  ;
          if ( $id ne '') { print "ID: GO:$id\n"; }
          ($name) = $line =~ /^name.\W+(.*)/       ;
          if ( $name ne '') { print "NAME: $name\n"; }    
          ($namespace) = $line =~ /^namespace.\W+(\w+)/       ;
          if ( $namespace ne '') { print "NAMESPACE: $namespace\n"; }    
       	  next;
        }
        
        # print values to file here
      
            # set OLD again
        $/="\n\n";

      }
    }

    exit 0;

    

    
