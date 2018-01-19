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

my $filename1 = shift @ARGV;
my $filename2 = shift @ARGV;
my $filename3 = shift @ARGV;
my $taxafile  = shift @ARGV;

unless ( $filename1 && $filename2 && $filename3 && $taxafile ) {
    print STDERR "Usage: \trdp.pl <filename1> <filename2> <filename3> <taxafile>\n";
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

open( my $md52id,  '>', 'md52id.txt' )     or die;
open( my $md52seq, '>', 'md52rnaseq.txt' ) or die;
open( my $md52tax, '>', 'md52taxid.txt' )  or die;

my ( $id, $md5s, $taxid, $sequence );

read_file($filename1);
read_file($filename2);
read_file($filename3);

exit 0;

sub read_file {
    my $filename = shift(@_);

    my $fh1 = new IO::Uncompress::Gunzip("$filename")
      or die "Cannot open '$filename': $!\n";

    # change EOL
    $/ = "\n//";

    while ( my $record = <$fh1> ) {
        ( $id, $md5s, $taxid, $sequence ) = ( '', '', '', '' );

        chomp $record;
        my @lines = split(/\n/, $record);
    
        for (my $i = 0; $i < scalar(@lines); $i++) {
            my $line = $lines[$i];
            
            if ( $line =~ /^LOCUS\s+(\w+)\W+/ ) {
                $id = $1;
                next;
            }

            if ( $line =~ /^\W+\/db_xref="taxon:(\d+)"/ ) {
                $taxid = $1;
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
}

sub print_record {
    if ( $md5s && $sequence && $id && $taxid && exists($taxamap{$taxid}) ) {
        print $md52seq "$md5s\t$sequence\n";
        print $md52tax "$md5s\t$taxid\n";
        print $md52id "$md5s\t$id\n";
    }
}
