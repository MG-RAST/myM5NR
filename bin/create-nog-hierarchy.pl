#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;

my $nog = {
    J => ["INFORMATION STORAGE AND PROCESSING", "Translation, ribosomal structure and biogenesis"],
    A => ["INFORMATION STORAGE AND PROCESSING", "RNA processing and modification"],
    K => ["INFORMATION STORAGE AND PROCESSING", "Transcription"],
    L => ["INFORMATION STORAGE AND PROCESSING", "Replication, recombination and repair"],
    B => ["INFORMATION STORAGE AND PROCESSING", "Chromatin structure and dynamics"],
    D => ["CELLULAR PROCESSES AND SIGNALING", "Cell cycle control, cell division, chromosome partitioning"],
    Y => ["CELLULAR PROCESSES AND SIGNALING", "Nuclear structure"],
    V => ["CELLULAR PROCESSES AND SIGNALING", "Defense mechanisms"],
    T => ["CELLULAR PROCESSES AND SIGNALING", "Signal transduction mechanisms"],
    M => ["CELLULAR PROCESSES AND SIGNALING", "Cell wall/membrane/envelope biogenesis"],
    N => ["CELLULAR PROCESSES AND SIGNALING", "Cell motility"],
    Z => ["CELLULAR PROCESSES AND SIGNALING", "Cytoskeleton"],
    W => ["CELLULAR PROCESSES AND SIGNALING", "Extracellular structures"],
    U => ["CELLULAR PROCESSES AND SIGNALING", "Intracellular trafficking, secretion, and vesicular transport"],
    O => ["CELLULAR PROCESSES AND SIGNALING", "Posttranslational modification, protein turnover, chaperones"],
    C => ["METABOLISM", "Energy production and conversion"],
    G => ["METABOLISM", "Carbohydrate transport and metabolism"],
    E => ["METABOLISM", "Amino acid transport and metabolism"],
    F => ["METABOLISM", "Nucleotide transport and metabolism"],
    H => ["METABOLISM", "Coenzyme transport and metabolism"],
    I => ["METABOLISM", "Lipid transport and metabolism"],
    P => ["METABOLISM", "Inorganic ion transport and metabolism"],
    Q => ["METABOLISM", "Secondary metabolites biosynthesis, transport and catabolism"],
    R => ["POORLY CHARACTERIZED", "General function prediction only"],
    S => ["POORLY CHARACTERIZED", "Function unknown"]
};

my $usage = "$0 --input <tabbed file: ID, key, function>\n";
my $input = '';
if ( ! GetOptions('input=s' => \$input) ) {
    print STDERR $usage;
    exit 1;
}
unless ( $input && (-s $input) ) {
    print STDERR $usage;
    exit 1;
}

open(INFILE, "<$input") || die "Can't open file $input\n";
while (my $line = <INFILE>) {
    chomp $line;
    my ($id, $key, $func) = split(/\t/, $line);
    if (exists $nog->{$key}) {
        # ID, level 1, level 2, level 3
        print STDOUT $id."\t".$nog->{$key}[0]."\t".$nog->{$key}[1]."\t".$func."\n";
    }
}
close(INFILE);

exit 0;
