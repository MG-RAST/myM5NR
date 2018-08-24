#!/usr/bin/perl

# bacmet
#
# two classes of genes
# PRE = predicted resistance  // BacMet_PRE.40556.fasta
# EXP = experimentally verified resistance // BacMet_EXP.704.fasta
# header format:
# >BAC0621|copA|tr|F4ZBX3|F4ZBX3_XANCI CopA OS=Xanthomonas citri subsp. citri GN=copA PE=4 SV=1
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record
my %good = map {$_=>1} (32..127);

my $filename     = shift @ARGV;
my $filename_pre = shift @ARGV;

unless ( $filename && $filename_pre ) {
    print STDERR "Usage: \tbacmet.pl <filename1> <filename2>\n";
    print STDERR
      " \te.g. bacmet.pl BacMet_EXP.704.fasta BacMet_PRE.40556.fasta\n";
    exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

my $fh2 = new IO::Uncompress::Gunzip("$filename_pre")
  or die "Cannot open '$filename': $!\n";

open( my $md52id,   '>', 'md52id.txt' )   or die;
open( my $md52func, '>', 'md52func.txt' ) or die;
open( my $md52seq,  '>', 'md52seq.txt' )  or die;

my ( $id, $md5s, $func, $seq );

while (<$fh1>) {

    # for every header line
    if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
        if ($seq) {
            process_record();
        }

#>BAC0002|abeS|tr|Q2FD83|Q2FD83_ACIBA QacEdelta1 SMR family efflux pump OS=Acinetobacter baumannii GN=qacEdelta1 PE=3 SV=1
#>BAC0290|opmD/nmpC|sp|P37592|OMPD_SALTY Outer membrane porin protein OmpD OS=Salmonella typhimurium (strain LT2 / SGSC1412 / ATCC 700720) GN=ompD PE=1 SV=2

        my $line = $_;
        $line =~ s/^>//g;

        $id = ( split( '\|', $line ) )[0];

        my $pos = index( $line, ' ' );    # find first space in string
        $func = substr( $line, $pos );
        ($func) = ( $func =~ /(.+)\W+OS=.+/ );
        $func =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
        $func =~ s/^\s+|\s+$//g;
        $func =~ s/^'|'$//g;
        $func =~ s/^"|"$//g;
        $func =~ s/^\s+|\s+$//g;
    }
    else {
        s/\s+//g;                         # remove whitespace
        $seq .= $_;                       # add sequence
    }
}

# print final record
if ($seq) {
    process_record();
}

close($fh1);

( $id, $md5s, $func, $seq ) = ( '', '', '', '' );

while (<$fh2>) {

    # for every header line
    if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
        if ($seq) {
            process_record();
        }

#>gi|118471459|ref|YP_889645.1| cadA gene product [Mycobacterium smegmatis str. MC2 155] [ctpD:Chr:Cobalt (Co), Nickel (Ni)]

        my $line = $_;
        my @parts = split( /\|/, $line );

        $id = $parts[1];
        $func = ( split( /\[/, $parts[-1] ) )[0];
        $func =~ s/^\s+|\s+$//g;
        $func =~ s/^'|'$//g;
        $func =~ s/^"|"$//g;
        $func =~ s/^\s+|\s+$//g;
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

close($fh2);

exit 0;

sub process_record {
    $seq  = uc($seq);
    $md5s = md5_hex($seq);

    # print the output
    if ( $md5s && $id && $func ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
        print $md52func "$md5s\t$func\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $func, $seq ) = ( '', '', '', '' );
}
