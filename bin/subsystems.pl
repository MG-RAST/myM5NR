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
use Digest::MD5 qw(md5_hex);

my %good = map {$_=>1} (32..127);

my $dirname = shift @ARGV;

unless ($dirname) {
    print STDERR "Usage: \tsubsystems.pl <DIRNAME>\n";
    exit 1;
}

open( MD5SEQ, '| uniq > md52seq.txt' ) or die;
open( MD5HIER, '| uniq > md52hierarchy.txt' ) or die;

print STDOUT "Parsing files in $dirname ...\n";
my $fcount = 0;

# FOR EACH FILE IN THE DIRECTORY
opendir( my $dirh, $dirname ) or die "Could not open $dirname\n";
while ( defined( my $filename = readdir($dirh) ) ) {

    next if $filename !~ /subsystems_.*/;
    open( my $fh1, '<', "$dirname/$filename" ) or die "Cannot open $dirname/$filename: $!\n";
    $fcount += 1;

    while ( my $line = <$fh1> ) {
        chomp $line;
        my ( $md5, undef, undef, undef, undef, $ss1, $ss2, $ss3, $role, $seq ) = split( /\t/, $line );

        unless ($ss2) {
            $ss2 = '-';
        }

        $ss1  =~ s/^\s+|\s+$//g;
        $ss2  =~ s/^\s+|\s+$//g;
        $ss3  =~ s/^\s+|\s+$//g;
        $role =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
        $role =~ s/\s+/ /g;
        $role =~ s/^\s+|\s+$//g;
        $role =~ s/^'|'$//g;
        $role =~ s/^"|"$//g;
        $role =~ s/^\s+|\s+$//g;

        # print the output
        if ( $md5 && $ss1 && $ss2 && $ss3 && $role && $seq ) {
            print MD5SEQ "$md5\t$seq\n";
            print MD5HIER "$md5\t$ss1\t$ss2\t$ss3\t$role\n";
        }
    }    # end of file
    close($fh1);

}    # end of read dir
closedir($dirh);
close(MD5SEQ);
close(MD5HIER);
print STDOUT "$fcount files parsed.\n";

print STDOUT "Retreiving unique subsystems ...\n";
my @hierarchy = `cut -f2,3,4,5 md52hierarchy.txt | sort -u`;
chomp @hierarchy;
print STDOUT scalar(@hierarchy) . " subsystem branches found.\n";

my $count = 1;
my $s_map = {};

print STDOUT "Creating md52id and id2hierarchy files ...\n";

open( IDHIER, '>id2hierarchy.txt' ) or die;
foreach my $s (@hierarchy) {
    my $num = () = $count =~ /\d/g;
    my $sid = "SS" . "0" x ( 5 - $num ) . $count;
    $s_map->{$s} = $sid;
    $count += 1;
    print IDHIER "$sid\t$s\n";
}
close(IDHIER);

open( MD5HIER, '<md52hierarchy.txt' ) or die;
open( MD5ID,   '>md52id.txt' )        or die;
while ( my $line = <MD5HIER> ) {
    chomp $line;
    my ( $md5, $branch ) = split( /\t/, $line, 2 );
    if ( exists $s_map->{$branch} ) {
        print MD5ID "$md5\t" . $s_map->{$branch} . "\n";
    }
}
close(MD5ID);
close(MD5HIER);

# cleanup
unlink 'md52hierarchy.txt';

print STDOUT "Done.\n";

exit 0;
