#!/usr/bin/perl

# SILVA
#
# extract md52seq_eggnog, id2tax, md52taxstring_silva
#
# >GAXI01000526.151.1950 Eukaryota;Opisthokonta;Holozoa;Metazoa (Animalia);Eumetazoa;Bilateria;Arthropoda;Hexapoda;Ellipura;Collembola;Tetrodontophora bielanensis (giant springtail)
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

my $filename = shift @ARGV;
my $taxafile = shift @ARGV;

unless ($filename && $taxafile) {
    print STDERR "Usage: \tsilva.pl <filename1> <taxafile>\n";
    exit 1;
}

# get NCBI taxa map
my %taxamap = ();
open( my $taxahdl, '<', $taxafile ) or die;
while (my $line = <$taxahdl>) {
    chomp $line;
    my @parts = split(/\t/, $line);
    my $tid   = shift @parts;
    my $taxa  = pop @parts;
    while (($taxa eq '-') || ($taxa =~ /^unknown/)) {
        $taxa = pop @parts;
    }
    $taxamap{$taxa} = $tid;
}
close($taxahdl);

my $fh1 = new IO::Uncompress::Gunzip("$filename")
  or die "Cannot open '$filename': $!\n";

open( my $md52id,    '>', 'md52id.txt' )     or die;
open( my $md52seq,   '>', 'md52rnaseq.txt' ) or die;
open( my $md52tax,   '>', 'md52tax.txt' )    or die;
open( my $md52taxid, '>', 'md52taxid.txt' )  or die;

my ( $id, $md5s, $tax, $taxid, $seq );

while (<$fh1>) {

    # for every header line
    if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
        if ($seq) {
            process_record();
        }

#>GAXI01000526.151.1950 Eukaryota;Opisthokonta;Holozoa;Metazoa (Animalia);Eumetazoa;Bilateria;Arthropoda;Hexapoda;Ellipura;Collembola;Tetrodontophora bielanensis (giant springtail)

        my $line = $_;
        chomp $line;
        ( $id, $tax ) = ( $line =~ /^>(\S+)\s(.+)$/ );
        
        # get NCBI taxid
        my $org = (split(/;/, $tax))[-1];
        if (exists $taxamap{$org}) {
            $taxid = $taxamap{$org};
        } else {
            my @parts   = split(/\s+/, $org);
            my $species = (scalar(@parts) > 1) ? $parts[0].' '.$parts[1] : $parts[0];
            my $genus   = $parts[0];
            if (exists $taxamap{$species}) {
                $taxid = $taxamap{$species};
            } elsif (exists $taxamap{$genus}) {
                $taxid = $taxamap{$genus};
            }
        }
    } else {
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
    if ( $id && $tax && $taxid ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
        print $md52tax "$md5s\t$tax\n";
        print $md52taxid "$md5s\t$taxid\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $tax, $taxid, $seq ) = ( '', '', '', '', '' );
}
