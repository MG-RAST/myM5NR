#!/usr/bin/perl

# uniprot --  convert uniprot flat files into as many MD5nr input files as possible
# no parameters, expects to be run from directory with *.dat files.
# all files created are two colum tables
#
# naming convention md52id_<source>.txt
#                   id2func_<source>.txt
#                   id2hierarchy_<source>.txt
#
# obtain: uniprot sequence, uniprot function, uniprot taxonomy, EC, CAZy, eggnog, pfam, interpro, go
#
# the parser is very brute force as bioperl and biopython will not extract all required fields
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

my %good = map {$_=>1} (32..127);

my $filename = shift @ARGV;
my $taxafile = shift @ARGV;

unless ($filename && $taxafile) {
    print STDERR "Usage: \tuniprot.pl <filename> <taxafile>\n";
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

my $fh1 = new IO::Uncompress::Gunzip("$filename") or die "Cannot open '$filename': $!\n";

open( my $md52id,        '>', 'md52id.txt' )        or die;
open( my $md52seq,       '>', 'md52seq.txt' )       or die;
open( my $md52func,      '>', 'md52func.txt' )      or die;
open( my $md52tax,       '>', 'md52taxid.txt' )     or die;
open( my $md52id_go,     '>', 'md52id_go.txt' )     or die;
open( my $md52id_ipr,    '>', 'md52id_ipr.txt' )    or die;
open( my $md52id_pfam,   '>', 'md52id_pfam.txt' )   or die;
open( my $md52id_kegg,   '>', 'md52id_kegg.txt' )   or die;
open( my $md52id_cazy,   '>', 'md52id_cazy.txt' )   or die;
open( my $md52id_ec,     '>', 'md52id_ec.txt' )     or die;
open( my $md52id_eggnog, '>', 'md52id_eggnog.txt' ) or die;
open( my $md52id_cog,    '>', 'md52id_cog.txt' )    or die;

my (
    $id,   $go, $kegg,   $md5s, $pfam, $ipr, $func,
    $cazy, $ec, $eggnog, $tax,  $cog,  $sequence
);

$/ = "\n//";

while ( my $record = <$fh1> ) {
    (
        $id,   $go, $kegg,   $md5s, $pfam, $ipr, $func,
        $cazy, $ec, $eggnog, $tax,  $cog,  $sequence
    ) = ( '', '', '', '', '', '', '', '', '', '', '', '', '' );

    chomp $record;
    my @lines = split( /\n/, $record );

    for ( my $i = 0 ; $i < scalar(@lines) ; $i++ ) {
        my $line = $lines[$i];

        if ( $line =~ /^ID\W+(\w+)\W+/ ) {
            $id = $1;
            next;
        }

        if ( $line =~ /^OX\W+NCBI_TaxID=(\d+)/ ) {
            $tax = $1;
            next;
        }

        if ( $line =~ /^DE\W+\w+Name:\W+Full=(.+);/ ) {
            $func = $1;
            $func =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
            # remove embedded IDs or organisms at end
            $func =~ s/\{.+?\}$//;
            $func =~ s/\[.+?\]$//;
            $func =~ s/\(.+?\)$//;
            # do we have non-informative descriptions
            if ($func =~ /\|/) {
                $func = '';
                next;
            }
            # whitespace cleanup
            $func =~ s/^\s+|\s+$//g;
            $func =~ s/^'|'$//g;
            $func =~ s/^"|"$//g;
            $func =~ s/^\s+|\s+$//g;
            next;
        }

        if ( $line =~ /^DR\W+InterPro\W+(IPR\w+)/ ) {
            $ipr = $1;
            next;
        }

        if ( $line =~ /^DR\W+CAZy;\W+(\w+);/ ) {
            $cazy = $1;
            next;
        }

        if ( $line =~ /^DR\W+Pfam;\W+(PF\w+)/ ) {
            $pfam = $1;
            next;
        }

        if ( $line =~ /^DR\W+KEGG;\W+(\w+):(\w+)/ ) {
            $kegg = "$1:$2";
            next;
        }

        if ( $line =~ /^DR\W+eggNOG;\W+(COG\d+);/ ) {
            $cog = $1;
            next;
        }

        if ( $line =~ /^DR\W+eggNOG;\W+(ENOG\w+);/ ) {
            $eggnog = $1;
            next;
        }

        if ( $line =~ /^DE\W+EC=(\d+).(\d+).(\d+).(\d+)\W+/ ) {
            $ec = "$1.$2.$3.$4";
            next;
        }

        if ( $line =~ /^DR\W+GO;\W+(GO:\w+)/ ) {
            $go = $1;
            next;
        }

        if ( $line =~ /^SQ/ ) {
            # get remaining lines from record and end loop
            $sequence = join( "", splice( @lines, $i + 1 ) );
            $sequence =~ s/\s+//g;
            $sequence = uc($sequence);
            $md5s     = md5_hex($sequence);
            last;
        }
    }    # end of record

    print_record();
}    # end of file

# print final record
print_record();

close($fh1);

exit 0;

sub print_record {
    if ( $md5s && $sequence && $id && $func && $tax && exists($taxamap{$tax}) ) {
        print $md52id "$md5s\t$id\n";
        print $md52seq "$md5s\t$sequence\n";
        print $md52func "$md5s\t$func\n";
        print $md52tax "$md5s\t$tax\n";
        # optional id mappings
        print $md52id_ipr "$md5s\t$ipr\n"       if ( $ipr    ne "" );
        print $md52id_cog "$md5s\t$cog\n"       if ( $cog    ne "" );
        print $md52id_eggnog "$md5s\t$eggnog\n" if ( $eggnog ne "" );
        print $md52id_pfam "$md5s\t$pfam\n"     if ( $pfam   ne "" );
        print $md52id_kegg "$md5s\t$kegg\n"     if ( $kegg   ne "" );
        print $md52id_go "$md5s\t$go\n"         if ( $go     ne "" );
        print $md52id_cazy "$md5s\t$cazy\n"     if ( $cazy   ne "" );
        print $md52id_ec "$md5s\t$ec\n"         if ( $ec     ne "" );
    }
}
