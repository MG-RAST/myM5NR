#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

my %good = map {$_=>1} (32..127);

my $usage = "$0 --input <EC genbank file> --class <EC class file>\n";
my $input = '';
my $class = '';
if ( ! GetOptions('input=s' => \$input, 'class=s' => \$class) ) {
    print STDERR $usage;
    exit 1;
}
unless ( $input && (-s $input) && $class && (-s $class) ) {
    print STDERR $usage;
    exit 1;
}

my $ec = {};
my ($cl, $scl);
open(CLFILE, "<$class") || die "Can't open file $class\n";
while (my $line = <CLFILE>) {
    chomp $line;
    if ($line =~ /^(\d)\. ?(-|\d+)\. ?(-|\d+)\.\-\s+(.*)\.$/) {
        if ($2 eq '-') {
            $cl = $4;
        } elsif ($3 eq '-') {
            $scl = $4;
        } else {
            $ec->{$1.".".$2.".".$3} = [$cl, $scl, $4];
        }
    }
}
close(CLFILE);

open(INFILE, "<$input") || die "Can't open file $input\n";
$/="\n//";
while (my $record = <INFILE>) {
    my ($id, $desc);
    foreach my $line (split(/\n/, $record)) {
        if ($line =~ /^ID\s+(\d\.\d+\.\d+\.\d+)/ ) {
            $id = $1;
            next;
        }
        if ($line =~ /^DE\s+(.+)\.$/) {
            $desc = $1;
            $desc =~ s/(.)/$good{ord($1)} ? $1 : ''/eg;
            $desc =~ s/^\s+|\s+$//g;
            $desc =~ s/^'|'$//g;
            $desc =~ s/^"|"$//g;
            $desc =~ s/^\s+|\s+$//g;
            next;
        }
    }
    unless ($id && $desc) {
        next;
    }
    foreach my $key (keys %$ec) {
        if ($id =~ /^$key\.\d+$/) {
            print STDOUT $id."\t".$ec->{$key}[0]."\t".$ec->{$key}[1]."\t".$ec->{$key}[2]."\t".$desc."\n";
            last;
        }
    }
}
close(INFILE);

exit 0;
