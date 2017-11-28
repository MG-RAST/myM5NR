#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

my $cazy = {
    GH  => ["Glycoside Hydrolases", "Glycoside Hydrolase Family"],
    GT  => ["GlycosylTransferases", "GlycosylTransferase Family"],
    PL  => ["Polysaccharide Lyases", "Polysaccharide Lyase Family"],
    CE  => ["Carbohydrate Esterases", "Carbohydrate Esterase Family"],
    AA  => ["Auxiliary Activities", "Auxiliary Activity Family"],
    CBM => ["Carbohydrate-Binding Modules", "Carbohydrate-Binding Module Family"]
};

my $usage = "$0 --input <tabbed file with IDs in second column>\n";
my $input = '';
if ( ! GetOptions('input=s' => \$input) ) {
    print STDERR $usage;
    exit 1;
}
unless ( $input && (-s $input) ) {
    print STDERR $usage;
    exit 1;
}

my @ids = `cut -f2 $input | sort -u`;
foreach my $id (@ids) {
    chomp $id;
    if ($id =~ /^([A-Z]+)(\d+)$/) {
        if (exists $cazy->{$1}) {
            # ID, level 1, level 2
            print STDOUT $id."\t".$cazy->{$1}[0]."\t".$cazy->{$1}[1]." ".$2."\n";
        }
    }
}

exit 0;
