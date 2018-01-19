#!/usr/bin/perl

# patric
#
# extract md52id, md52seq.
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);

my $dirname = shift @ARGV;
my $taxafile = shift @ARGV;

unless ($dirname && $taxafile) {
    print STDERR "Usage: \tpatric.pl <DIRNAME> <taxafile>\n";
    exit 1;
}

open( my $md52id,   '>', 'md52id.txt' )    or die;
open( my $md52seq,  '>', 'md52seq.txt' )   or die;
open( my $md52func, '>', 'md52func.txt' )  or die;
open( my $md52tax,  '>', 'md52taxid.txt' ) or die;

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

# FOR EACH FILE IN THE DIRECTORY
opendir( DIR, $dirname ) or die "Could not open $dirname\n";

my ( $id, $md5s, $func, $taxid, $seq );

while ( my $filename = readdir(DIR) ) {

    next if $filename !~ /.*\.faa/;

    open( my $fh1, '<', "$dirname/$filename" )
      or die "Cannot open $dirname/$filename: $!\n";

    while (<$fh1>) {

        # for every header line
        if (/^>/) {

        # if we already have a sequence ...  ## need to take care of last record
            if ($seq) {
                process_record();
            }

#>fig|101571.178.peg.5|   hypothetical protein   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|101571.178.peg.6|WL35_01550|   Putative outer membrane lipoprotein   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|611304.3.peg.4028|MtubK8_010100008408|VBIMycTub343819_4028|   (2E,6Z)-farnesyl diphosphate synthase (EC 2.5.1.68)   [Mycobacterium africanum K85 | 611304.3]
#>fig|79879.3.peg.5883|   hypothetical protein   [[Bacillus] clarkii strain DSM 8720 | 79879.3]
#>fig|1494590.3.peg.2363|ATN84_09125|   4-[[4-(2-aminoethyl)phenoxy]-methyl]-2-furanmethanamine-glutamate synthase   [Paramesorhizobium deserti strain A-3-E | 1494590.3]
#>fig|911117.5.peg.997|   4-[[4-(2-aminoethyl)phenoxy]-methyl]-2-furanmethanamine-glutamate synthase   [Methanobrevibacter smithii TS145B | 911117.5]

            my $line = $_;
            chomp $line;
            
            ($id, $func, undef) = split(/   /, $line);

            my @subids = split( /\|/, $id );
            
            $id = "fig|" . $subids[1];
            $taxid = (split( /\./, $subids[1] ))[0];
            
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
        }
        else {
            s/\s+//g;    # remove whitespace
            $seq .= $_;  # add sequence
        }
    }    # end of file

    # print final record
    if ($seq) {
        process_record();
    }

    close($fh1);

}    # end of read dir

closedir(DIR);

exit 0;

sub process_record {
    $seq  = uc($seq);
    $md5s = md5_hex($seq);

    # print the output
    if ( $id && $func && $taxid && exists($taxamap{$taxid}) ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$seq\n";
        print $md52func "$md5s\t$func\n";
        print $md52tax "$md5s\t$taxid\n";
    }

    # reset the values for the next record
    ( $id, $md5s, $func, $taxid, $seq ) = ( '', '', '', '', '' );
}
