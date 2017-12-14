#!/usr/bin/env perl

use strict;
use warnings;

if (-t STDIN) {
    print STDERR "usage: tabbed_file < $0 > fasta_file\n";
    exit 1;
} else {
    foreach my $line (<STDIN>) {
        process_line($line);
    }
}

exit 0;

sub process_line {
    my ($line) = @_;
    chomp $line;
    my ($md5, $seq) = split(/\t/, $line);
    if ($seq) {
        print ">".$md5."\n".$seq."\n";
    }
}
