#!/usr/bin/perl

# generic genbank parser
#
# extract seq, func, tax, id
# the parser is very brute force as bioperl and biopython will not extract all required fields
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

my %good = map {$_=>1} (32..127);

my $dirname = shift @ARGV;
my $taxafile = shift @ARGV;

unless ($dirname && $taxafile) {
    print STDERR "Usage: \trefseq.pl <DIRNAME> <taxafile>\n";
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
open( my $md52tax,  '>', 'md52taxid.txt' ) or die;

# FOR EACH FILE IN THE DIRECTORY
opendir( DIR, $dirname ) or die "Could not open $dirname\n";

my ( $id, $md5s, $func, $tax, $sequence );

while ( my $filename = readdir(DIR) ) {

    next if $filename !~ /.*\.gpff.gz/;
    my $fh1 = new IO::Uncompress::Gunzip("$dirname/$filename") or die "Cannot open $dirname/$filename': $!\n";

    # change EOL
    $/ = "//\n";

    while ( defined( my $record = <$fh1> ) ) {
        ( $id, $md5s, $func, $tax, $sequence ) = ( '', '', '', '', '' );

        # find definition (might be multi line)
        if ( $record =~ /\nDEFINITION\W+(.*?)\[.*\]\./s ) {
            $func = $1;
            # collapse whitespace, remove newlines
            $func =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
            $func =~ s/\s+/ /gs;
            # clean terms
            $func =~ s/MULTISPECIES://g;
            $func =~ s/RecName://g;
            $func =~ s/Short=.*//g;
            # function cleanup
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
            my $len = length($record);
            if ( $len == 1 ) { next; }
        }
        
        chomp $record;
        my @lines = split(/\n/, $record);
    
        for (my $i = 0; $i < scalar(@lines); $i++) {
            my $line = $lines[$i];

            if ( $line =~ /^LOCUS\W+(\w+)\W+/ ) {
                $id = $1;
                next;
            }

            if ( $line =~ /^\W+\/db_xref="taxon:(\d+)"/ ) {
                $tax = $1;
                next;
            }
            
            if ( $line =~ /^ORIGIN/ ) {
                # get remaining lines from record and end loop
                $sequence = join("", splice(@lines, $i+1));
                $sequence =~ s/\s+//g;
                $sequence =~ s/[0-9]+//g;
                $sequence = uc($sequence);
                $md5s     = md5_hex($sequence);
                last;
            }
        }    # end of record

        print_record();
    }    # end of file

    # print final record
    print_record();

    # reset EOL
    $/ = "\n";

    close($fh1);

}    # end of read dir

exit 0;

sub print_record {
    if ( $md5s && $sequence && $id && $func && $tax && exists($taxamap{$tax}) ) {
        print $md52seq "$md5s\t$sequence\n";
        print $md52func "$md5s\t$func\n";
        print $md52tax "$md5s\t$tax\n";
        print $md52id "$md5s\t$id\n";
    }
}
