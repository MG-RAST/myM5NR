#!/usr/bin/perl

# genbank
#
# extract md52id, md52seq.
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
    print STDERR "Usage: \tgenbank.pl <filename1> \n";
    exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

open( my $md52id,   '>', 'md52id.txt' )   or die;
open( my $md52seq,  '>', 'md52seq.txt' )  or die;
open( my $md52func, '>', 'md52func.txt' ) or die;

my ( $id, $md5s, $func, $seq );

while (<$fh1>) {

    # for every header line
    if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
        if ($seq) {
            process_record();
        }

        # >WP_003131952.1 30S ribosomal protein S18 [Lactococcus lactis]
        my $line = $_;

        # we only read the first record, they are ^A separated
        my $maxlen = index( $line, "\x01" );

        my @words = split( / /, substr( $line, 0, $maxlen ) );
        $id = substr( $words[0], 1 );
        my $pos = index( $line, '[' );
        my $len = length($id);
        $func = substr( $line, $len + 1, $pos - $len );
        $func =~ s/MULTISPECIES:\ //g;
        $func =~ s/RecName:\ Full=//g;
        $func =~ s/Short=.*//g;

# we still need to split off some CTRL-A tails ; should have been caught before but isn't
        $func =~ s/\x01.*//g;
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
    if ( $id && $func ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
        print $md52func "$md5s\t$func\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $func, $seq ) = ( '', '', '', '' );
}
