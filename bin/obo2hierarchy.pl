#!/usr/bin/perl

# obo2hierarchy
# generic obo file to hierarchy converter
# parameter is just the filename
#
# the parser is very brute force as bioperl, etc will not extract all required fields
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

my $filename = shift @ARGV;

unless ($filename) {
    print STDERR "Usage: \tobo2hierarchy.pl <filename1> \n";
    print STDERR " \te.g. obo2hierarchy.pl file.obo\n";
    exit 1;
}

$/ = "\n\n";

open( my $fh1,     '<', $filename )          or die;
open( my $id2hier, '>', 'id2hierarchy.txt' ) or die;

my ( $id, $name, $namespace, $hier1 );

while ( my $record = <$fh1> ) {
    ( $id, $name, $namespace, $hier1 ) = ( '', '', '', '' );

    # ignore all non Term entries
    next if ( $record !~ /\[Term\].*/ );

    foreach my $line ( split /\n/, $record ) {

        if ( $line =~ /^id:\W+(\w+):(\d+)/ ) {
            $id = "$1:$2";
            next;
        }
        if ( $line =~ /^name:\W+(.*)/ ) {
            $name = $1;
            next;
        }
        if ( $line =~ /^namespace:\W+(\w+)/ ) {
            $namespace = $1;
            next;
        }
        if ( $line =~ /^is_a:\W+(\w+):\d+\W+!\W+(.*)/ ) {
            $hier1 = "$1:$2";
            next;
        }

    }    # end of record

    if ( $id && $namespace && $hier1 && $name ) {
        print $id2hier "$id\t$namespace\t$hier1\t$name\n";
    }

}    # end of file

close($fh1);

exit 0;

