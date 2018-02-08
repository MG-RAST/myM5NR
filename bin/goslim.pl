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
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

use Getopt::Long;

my %good = map {$_=>1} (32..127);

my $Swiss_prot_file;
my $TrEmble_file;
my $verbose;

my $filename = shift @ARGV;

unless ( $filename ) {
    print STDERR "Usage: \tgoslim.pl <filename1> \n";
    print STDERR " \te.g. goslim.pl goslim_metagenomics.obo\n";
    exit 1;
}

$/ = "\n\n";

open (my $fh1, '<', $filename) or die;
open( my $id2hier, '>', 'id2hierarchy.txt' ) or die;

my ( $id, $name, $namespace, $hier1 );

while ( my $record = <$fh1> ) {
    ( $id, $name, $namespace, $hier1 ) = ( '', '', '', '' );

    # ignore all non Term entries
    next if ( $record !~ /\[Term\].*/ );
    
    foreach my $line ( split /\n/, $record ) {

        if ( $line =~ /^id.\W+(GO:\d+)/ ) {
            $id = $1;
            next;
        }
        if ( $line =~ /^name.\W+(.*)/ ) {
            $name = $1;
            $name =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
            $name =~ s/^\s+|\s+$//g;
            $name =~ s/^'|'$//g;
            $name =~ s/^"|"$//g;
            $name =~ s/^\s+|\s+$//g;
            next;
        }
        if ( $line =~ /^namespace.\W+(\w+)/ ) {
            $namespace = $1;
            next;
        }
        if ( $line =~ /^is_a:\W+GO:\d+\W+!\W+(.*)/ ) {
            $hier1 = $1;
            next;
        }

    }    # end of record

    if ( $id && $namespace && $hier1 && $name ) {
        print $id2hier "$id\t$namespace\t$hier1\t$name\n";
    }

}    # end of file

close($fh1);

exit 0;
