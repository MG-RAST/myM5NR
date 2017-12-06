#!/usr/bin/perl

# refseq
#
# extract md52id, md52seq.id2tax, md52tax
#
# >WP_027747122.1 S-(hydroxymethyl)mycothiol dehydrogenase [Streptomyces sp. CNH287]
#MAQEVRGVIAPGKDEPVRTETIVVPDPGPGEAVVEVRACGVCHTDLHYRQGGINDEFPFLLGHEAAGVVESVGEGVTEVA

#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record

my $dirname = shift @ARGV;

unless ($dirname) {
    print STDERR "Usage: \trefseq.pl <DIRNAME>\n";
    exit 1;
}

open( my $md52id,   '>', 'md52id.txt' )   or die;
open( my $md52seq,  '>', 'md52seq.txt' )  or die;
open( my $md52func, '>', 'md52func.txt' ) or die;
open( my $md52tax,  '>', 'md52tax.txt' )  or die;

# FOR EACH FILE IN THE DIRECTORY
opendir( DIR, $dirname ) or die "Could not open $dirname\n";

my ( $id, $md5s, $func, $tax, $sequence );

while ( my $filename = readdir(DIR) ) {

    next if $filename !~ /.*\.gpff.gz/;
    print "WORKING ON: $filename\n";

    my $fh1 = new IO::Uncompress::Gunzip("$dirname/$filename")
      or die "Cannot open $dirname/$filename': $!\n";

    # change EOL
    $/ = "//\n";

    while ( defined( my $record = <$fh1> ) ) {
        ( $id, $md5s, $func, $tax, $sequence ) = ( '', '', '', '', '' );

        # find definition (might be multi line)
        if ( $record =~ /\nDEFINITION\W+(.*)\[.*\]\./s ) {
            $func = $1;
        }
        else {
            my $len = length($record);
            if ( $len == 1 ) { next; }
        }

        foreach my $line ( split /\n/, $record ) {

            if ( $line =~ /^LOCUS\W+(\w+)/ ) {
                $id = $1;
                next;
            }

            if ( $line =~ /\W+.db_xref=\"taxon:(\d+)"+/ ) {
                $tax = $1;
                next;
            }

            # parse sequence, generate md5
            if ( $line =~ /^ORIGIN/ ) {
                my @lines = split( 'ORIGIN', $record );

               # split the record at the correct position to catch the sequences
                $sequence = $lines[1];

             # join lines, remove the first list as well as the record separator
                $sequence =~ s/^(.*\n)//;
                $sequence =~ tr / \n\/\/[0-9]//ds;
                chomp $sequence;
                $sequence = lc($sequence);
                $md5s     = md5_hex($sequence);
                next;
            }    # end of ORIGIN case
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
    if ( $md5s && $sequence && $id ) {
        print $md52seq "$md5s\t$sequence\n";
        print $md52func "$md5s\t$func\n";
        print $md52tax "$md5s\t$tax\n";
        print $md52id "$md5s\t$id\n";
    }
}
