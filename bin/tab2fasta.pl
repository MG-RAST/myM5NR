#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
 
STDIN->blocking(0);

my $line = <STDIN>;
if (defined $line) {
    process_line($line);
    foreach my $line (<STDIN>) {
        process_line($line);
    }
} else {
    print STDERR "usage: tabbed_file < $0 > fasta_file";
    exit 1;
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
