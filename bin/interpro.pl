#!/usr/bin/perl

# interpro
#
# convert interpro file
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record

my $filename = shift @ARGV;

unless ($filename) {
    print STDERR "Usage: \tinterpro.pl <filename1> \n";
    exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

open( my $id2func, '>', 'id2func.txt' ) or die;
open( my $id2go,   '>', 'id2go.txt' )   or die;

my ( $id, $md5s, $func, $go );

while ( my $line = <$fh1> ) {
    next if $line =~ /^!.*/;

    #InterPro:IPR000015 Outer membrane usher protein > GO:transport ; GO:0006810
    ( $id, $func, $go ) = ( $line =~ /InterPro:(\w+)\W+(.+)>.+;\W+GO:(\d+)/ );

    print $id2func "$id\t$func\n";
    print $id2go "$id\t$go\n";
}

close($fh1);

exit 0;
