#!/usr/bin/perl

# generic genbank parser
#
# extract seq, func, tax, id
# the parser is very brute force as bioperl and biopython will not extract all required fields
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

my $filename1 = shift @ARGV;
my $filename2 = shift @ARGV;
my $filename3 = shift @ARGV;

unless ( $filename1 && $filename2 && $filename3 ) {
    print STDERR "Usage: \tgenbank.pl <filename1> <filename2> <filename3>\n";
    exit 1;
}

open( my $md52id,  '>', 'md52id.txt' )     or die;
open( my $md52seq, '>', 'md52rnaseq.txt' ) or die;
open( my $md52tax, '>', 'md52tax.txt' )    or die;

my ( $id, $md5s, $tax, $sequence );

read_file($filename1);
read_file($filename2);
read_file($filename3);

exit 0;

sub read_file {
    my $filename = shift(@_);

    my $fh1 = new IO::Uncompress::Gunzip("$filename")
      or die "Cannot open '$filename': $!\n";

    # change EOL
    $/ = "\n//";

    while ( my $record = <$fh1> ) {
        ( $id, $md5s, $tax, $sequence ) = ( '', '', '', '' );

        foreach my $line ( split /\n/, $record ) {

            # LOCUS       S000494589               454 bp    rRNA    linear   BCT 15-Jun-2007
            if ( $line =~ /^LOCUS\s+(\w+)\W+.*/ ) {
                $id = $1;
                next;
            }

            # /db_xref="taxon:77133"
            if ( $line =~ /^\W+\/db_xref="taxon:(\w+)"/ ) {
                $tax = $1;
                next;
            }

            # parse sequence, generate md5
            if ( $line =~ /^ORIGIN/ ) {
                my @lines = split( 'ORIGIN', $record );

                # split the record at the correct position to catch the sequences
                $sequence = $lines[1];

                # join lines, remove the first list as well as the record separator
                $sequence =~ s/^(.*\n)//;
                $sequence =~ tr /[0-9] \n\///ds;
                chomp $sequence;
                $sequence = lc($sequence);
                $md5s     = md5_hex($sequence);
                next;
            }    # end of ORIGIN case
        }    # end of record

        print_record();
    }    # end of file

    # print final record
    print_record();

    # reset EOL
    $/ = "\n";

    close($fh1);
}

sub print_record {
    if ( $md5s && $sequence && $id ) {
        print $md52seq "$md5s\t$sequence\n";
        print $md52tax "$md5s\t$tax\n";
        print $md52id "$md5s\t$id\n";
    }
}
