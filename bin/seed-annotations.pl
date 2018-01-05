#!/usr/bin/perl

# seed annotations
#
# extract md52id, md52seq. md52id, id2func
#
#a6e173167c03943a8709615b16285845        fig|470865.2.peg.20     Phage protein   44AHJD-like phages Staphylococcus phage SAP-2   SEED    MTEFEEIVKPDDKEPTEEPTEEPTEEPTEDKTVETIEEENKNKLEP..
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);

my $filename = shift @ARGV;

unless ($filename) {
    print STDERR "Usage: \tseed-annotations.pl <filename>\n";
    exit 1;
}

open( my $md52id,   '>', 'md52id.txt' )   or die;
open( my $md52seq,  '>', 'md52seq.txt' )  or die;
open( my $md52func, '>', 'md52func.txt' ) or die;

open( my $fh1, '<', "$filename" ) or die "Cannot open $filename: $!\n";

while ( my $line = <$fh1> ) {

    chomp $line;
    my ( $md5, $id, $func, undef, undef, $seq ) = split( /\t/, $line );
    
    # function cleanup
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
    if ( $md5 && $id && $func && $seq ) {
        print $md52id "$md5\t$id\n";
        print $md52seq "$md5\t$seq\n";
        print $md52func "$md5\t$func\n";
    }
}

close($fh1);

exit 0;
