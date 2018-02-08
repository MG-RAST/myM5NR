#!/usr/bin/perl

# seed annotations
#
#a6e173167c03943a8709615b16285845        fig|470865.2.peg.20     Phage protein   44AHJD-like phages Staphylococcus phage SAP-2   SEED    MTEFEEIVKPDDKEPTEEPTEEPTEEPTEDKTVETIEEENKNKLEP..
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);

my %good = map {$_=>1} (32..127);

my $filename = shift @ARGV;
my $taxafile = shift @ARGV;

unless ($filename && $taxafile) {
    print STDERR "Usage: \tseed-annotations.pl <filename> <taxafile>\n";
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
    $taxamap{$tid} = $taxa;
}
close($taxahdl);

open( my $md52id,   '>', 'md52id.txt' )    or die;
open( my $md52seq,  '>', 'md52seq.txt' )   or die;
open( my $md52func, '>', 'md52func.txt' )  or die;
open( my $md5tax,   '>', 'md52taxid.txt' ) or die;

open( my $fh1, '<', "$filename" ) or die "Cannot open $filename: $!\n";

while ( my $line = <$fh1> ) {

    chomp $line;
    my ( $md5, $id, $func, undef, undef, $seq ) = split( /\t/, $line );
    
    my $taxid = (split(/\./, (split(/\|/, $id))[1]))[0];
    
    # function cleanup
    $func =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
    $func =~ s/\s+/ /g;
    $func =~ s/^\s+|\s+$//g;
    $func =~ s/^'|'$//g;
    $func =~ s/^"|"$//g;
    $func =~ s/^\s+|\s+$//g;
    $func =~ s/\{.+?\}$//;
    $func =~ s/\[.+?\]$//;
    $func =~ s/\(.+?\)$//;
    $func =~ s/\s+$//;

    # print the output
    if ( $md5 && $id && $func && $seq && $taxid && exists($taxamap{$taxid}) ) {
        print $md52id "$md5\t$id\n";
        print $md52seq "$md5\t$seq\n";
        print $md52func "$md5\t$func\n";
        print $md5tax "$md5\t$taxid\n";
    }
}

close($fh1);

exit 0;
