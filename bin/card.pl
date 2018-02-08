#!/usr/bin/perl

# card
#
# extract md52id, md52hier, md52seq, md52func
# header format:
# >gb|AFJ59957.1|ARO:3001989|CTX-M-130 [Escherichia coli]
# >gb|AEX08599.1|ARO:3002356|NDM-6 [Escherichia coli]
# >gb|BAP68758.1|ARO:3001855|ACT-35 [Enterobacter cloacae]
# >gb|AAF61417.1|ARO:3002244|CARB-5 [Acinetobacter calcoaceticus subsp. anitratus]
# >gb|AAP74657.1|ARO:3000600|Erm(34) [Bacillus clausii]

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

my $filename = shift @ARGV;

unless ($filename) {
    print STDERR "Usage: \tcard.pl <filename>\n";
    print STDERR " \te.g. card.pl card.fasta\n";
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

# >gb|AFJ59957.1|ARO:3001989|CTX-M-130 [Escherichia coli]
# >gb|AEX08599.1|ARO:3002356|NDM-6 [Escherichia coli]
# >gb|BAP68758.1|ARO:3001855|ACT-35 [Enterobacter cloacae]
# >gb|AAF61417.1|ARO:3002244|CARB-5 [Acinetobacter calcoaceticus subsp. anitratus]
# >gb|AAP74657.1|ARO:3000600|Erm(34) [Bacillus clausii]

        my $line = $_;
        chomp $line;
        
        my @fields = split(/\|/, $line);
        $id = $fields[2];
        
        my @parts = split(/ \[/, $fields[3]);
        $func = $parts[0];
        $func =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
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

close($fh1);

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
