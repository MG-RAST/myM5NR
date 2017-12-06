#!/usr/bin/perl

# greengenes
#
# extract md52id, md52seq, id2tax
#

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
    print STDERR "Usage: \tgreengenes.pl <filename1> \n";
    exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

open( my $md52id,  '>', 'md52id.txt' )     or die;
open( my $md52seq, '>', 'md52rnaseq.txt' ) or die;
open( my $md52tax, '>', 'md52tax.txt' )    or die;

my ( $id, $md5s, $tax, $seq );

while (<$fh1>) {

    # for every header line
    if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
        if ($seq) {
            process_record();
        }

# >14 AF068820.2 hydrothermal vent clone VC2.1 Arc13 k__Archaea; p__Euryarchaeota; c__Thermoplasmata; o__Thermoplasmatales; f__Aciduliprofundaceae; otu_204
        ( $id, $tax ) = (/>(\d+)\W+\w+.\d+\W+(.*)/);
    }
    else {
        s/\s+//g;    # remove whitespace
        $seq .= $_;  # add sequence
    }
}

# print final record
if ($seq) {
    process_record();
}

close($fh1);

exit 0;

sub process_record {
    $seq  = lc($seq);
    $md5s = md5_hex($seq);

    # print the output
    if ( $id && $tax ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
        print $md52tax "$md5s\t$tax\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $tax, $seq ) = ( '', '', '', '' );
}
