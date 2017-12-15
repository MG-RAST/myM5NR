#!/usr/bin/perl

# subsystems
#
# extract md52id, md52seq. md52id, md52subsystems, id2subsystems
#
#47326e4716f40d23d3d5a899ca6ef11e        fig|340185.3.peg.4788   Zinc resistance-associated protein              Subsystems      Virulence       Resistance to antibiotics
#and toxic compounds   Zinc resistance Zinc resistance-associated protein      MSKNDSLPAAGESFLLVYHARLPVISAFHRWHGRCNTRSKTTTGGLTMKRNTKIALVMMALSAMAMGSTSAFAHGGHGMWQQNAAPLTSEQQ
#TAWQKIHNDFYAQSSALQQQLVTKRYEYNALLAANPPDSSKINAVAKEMENLRQSLDELRVKRDIAMAEAGIPRGTGMGMGYGGCGGGGHMGMGHW
#
# folker@anl.gov

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;

my $dirname = shift @ARGV;

unless ($dirname) {
    print STDERR "Usage: \tsubsystems.pl <DIRNAME>\n";
    exit 1;
}

open( my $md52id,        '>', 'md52id.txt' )        or die;
open( my $md52seq,       '>', 'md52seq.txt' )       or die;
open( my $id2hierarchy,  '>', 'id2hierarchy.txt' )  or die;

# FOR EACH FILE IN THE DIRECTORY
opendir( my $dirh, $dirname ) or die "Could not open $dirname\n";

while ( defined( my $filename = readdir($dirh) ) ) {

    next if $filename !~ /subsystems_.*/;

    open( my $fh1, '<', "$dirname/$filename" )
      or die "Cannot open $dirname/$filename: $!\n";

    while ( my $line = <$fh1> ) {

        chomp $line;
        my ( $md5, $id, undef, undef, undef, $ss1, $ss2, $ss3, $role, $seq ) = split( /\t/, $line );

        unless ($ss2) {
            $ss2 = '-';
        }

        # print the output
        if ( $md5 && $id && $ss1 && $ss2 && $ss3 && $role && $seq ) {
            print $md52id "$md5\t$id\n";
            print $md52seq "$md5\t$seq\n";
            print $id2hierarchy "$id\t$ss1\t$ss2\t$ss3\t$role\n";
        }
    }    # end of file
    close($fh1);

}    # end of read dir

closedir($dirh);
