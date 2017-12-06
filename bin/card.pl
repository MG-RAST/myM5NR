#!/usr/bin/perl

# card
#
# extract md52id, md52seq. md52func, id2func, md52tax, id2tax
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

my $filename = shift @ARGV;
my $taxonomy = shift @ARGV;

unless ( $filename && $taxonomy ) {
    print STDERR "Usage: \tcard.pl <filename> <taxonomy>\n";
    print STDERR " \te.g. card.pl card.fasta ncbi_taxonomy.csv\n";
    exit 1;
}

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

open( my $ncbitax, '<', $taxonomy ) or die "cannot open $taxonomy";

open( my $md52id,   '>', 'md52id.txt' )   or die;
open( my $md52hier, '>', 'md52hier.txt' ) or die;
open( my $md52seq,  '>', 'md52seq.txt' )  or die;
open( my $md52tax,  '>', 'md52tax.txt' )  or die;
open( my $md52func, '>', 'md52func.txt' ) or die;

## generate a hash with NCBI taxnomy string to ID mapping
my %ncbihash = ();
while ( my $line = <$ncbitax> ) {
    my ( $id, $taxstring, $junk ) = ( split /,/, $line );
    $taxstring =~ s/"//g;
    $ncbihash{$taxstring} = $id;
}

my ( $id, $md5s, $func, $tax, $card, $seq );

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
        my @fields = ( split '\|', $line );
        $id   = $fields[1];
        $card = $fields[2];
        ( $func, $tax ) = ( $fields[3] =~ /^(\S+)\s\[(.+)\]$/ );
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
    if ( $id && $func && $tax ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
        print $md52func "$md5s\t$func\n";
        print $md52hier "$md5s\t$card\n";
        print $md52tax "$md5s\t$ncbihash{$tax}\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $func, $tax, $card, $seq ) = ( '', '', '', '', '', '' );
}
