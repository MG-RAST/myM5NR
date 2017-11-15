#!/usr/bin/perl

# interpro
# 
# convert interpro file 
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
  print STDERR "Usage: \tinterpro.pl <filename1> \n";
  exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;
       

open(my $id2func_interpro, '>',   'id2func_interpro.txt') or die ;
open(my $id2go_interpro, '>',   'id2go_interpro.txt') or die ;

# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $func='';  my $go='';  my $line;

while ($line = <$fh1>) {
  
  next if $line =~ /^!.*/;
  
  #InterPro:IPR000015 Outer membrane usher protein > GO:transport ; GO:0006810

  ($id,$func,$go) = ($line =~ /InterPro:(\w+)\W+(.+)>.+;\W+GO:(\d+)/); 
#  ($id,$func,$go) = ($line =~ /InterPro:(\w+)\W+(\w+)>GO:(.*);GO:(\d+)$/);
  
 # print "LINE\t$line\n";
#  print "ID: $id\nFUNC: $func\n GO:$go\n";
  
  print $id2func_interpro "$id\t$func\n";
  print $id2go_interpro "$id\t$go\n";

}  # end of line  



close ($fh1);

