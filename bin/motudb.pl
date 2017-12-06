#!/usr/bin/perl

# motuDB.pl
#  see http://www.bork.embl.de/software/mOTU/
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

my $filename = shift @ARGV;

unless ($filename) {
    print STDERR "Usage: \tmotudb.pl <filename1> \n";
    print STDERR " \te.g. motudb.pl mOTU.v1.padded	\n";
    exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

open( my $md52id,  '>', 'md52id.txt' )  or die;
open( my $md52seq, '>', 'md52seq.txt' ) or die;

my ( $id, $md5s, $seq );

while (<$fh1>) {

    # for every header line
    if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
        if ($seq) {
            process_record();
        }

        ($id) = (/^>(.*)\W\d+\W\d+/);
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
    $seq  = uc($seq);
    $md5s = md5_hex($seq);

    # print the output
    if ($id) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $seq ) = ( '', '', '' );
}
