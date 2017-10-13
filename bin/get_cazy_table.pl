#!/usr/bin/perl -w
#######################################################################################################
#
# This script fetch and parse CAZy enzyme web pages to extract CAZy proteins 
# OUTPUT: A tab delimited file with following columns: 
#              CAZy family, ProteinID, Organism, ec, genbank protein accession, uniprotID 
#
# Author: Mustafa Syed
# Note: This script extract data from CAZy web pages and author bears no legal reponsibility
#
#######################################################################################################
use LWP::Simple;
use LWP::UserAgent;

if (@ARGV == 0) {
	die "please provide output file as argument";
}

my $output_file = $ARGV[0]; # e.g. cazy_all_v042314.txt

open OUTFILE, "> ".$output_file or die "could not open out file";
print OUTFILE "family_id\tprotein\torganism\tec\tgbk_prot\tuniprot\n";

my %hash_family = ('GH' => '133', 'GT' => '95', 'PL' => '23', 'CE' => '16', 'CBM' => '69', 'AA' => '11');

my %hash_org_protein_total;
foreach my $family(keys %hash_family)
{
    my $family_cnt = $hash_family{$family};

    for(my $i=1; $i<=$family_cnt; $i++)
    {
	my $family_id = $family.$i;
	my $url = 'http://www.cazy.org/'.$family_id.'_all.html';
	my $efetch_out = get($url);
	my @pages = $efetch_out =~ /_all\.html\?debut_PRINC\=(\d+?)\#pagination_PRINC\'/g;

	if($#pages > -1)
	{
	    my %seen;
	    foreach my $num(@pages)
	    {
		next if($seen{$num});
		$seen{$num}=1;
		my $url = "http://www.cazy.org/$family_id"."_all.html?debut_PRINC=".$num."#pagination_PRINC";
		print "\n$url\n";
		my $efetch_out = get($url);

		my $result = &parse_page($family_id, $efetch_out);
	    }
#FIRST PAGE
	    my $url = "http://www.cazy.org/".$family_id."_all.html#pagination_PRINC";
	    print "\n$url\n";
	    my $efetch_out = get($url);
	    my $result = &parse_page($family_id, $efetch_out);
	}
	else
	{
	   my $result =  &parse_page($family_id, $efetch_out);
	}

    }
}

close(OUTFILE);

####################################################################################################################
sub parse_page()
{
    my ($family_id, $efetch_out) = @_;
    
    my @array_tables = split/<\/table>/,$efetch_out;
    
    foreach my $table(@array_tables)
    {
	if(($table =~ /GenBank/) and ($table =~ /EC\#/))
	{
	    my @array_lines = split/<\/tr>/,$table;
	    foreach my $line(@array_lines)
	    {
		next if(($line =~ /GenBank/) and ($line =~ /EC\#/));
		$line =~ s/\s{2,}/ /g;
		$line =~ s/\'//g;
		my @array_columns = split/<\/td>/,$line;
		next if(($#array_columns < 4) or ($array_columns[2] !~ /\w+/));
		
		my $protein = $array_columns[0];
		my $ec = $array_columns[1];
		my $organism = $array_columns[2];
		my $ncbi = $array_columns[3];
		my $uniprot = $array_columns[4];
		my $pdb = $array_columns[5];
		my $something = $array_columns[6];
		
		my $gbk_str='';
# 042314: not every protein in hyper link
#		my @gbk_protein = split/<\/a>/,$ncbi;
		my @gbk_protein = split/\<br\>/,$ncbi;
		
		$protein =~ s/<(.*?)\>|^\s+|\s+$|&nbsp;|&nbsp//g;
		$ec =~ s/<(.*?)\>|^\s+|\s+$|&nbsp;|&nbsp//g;
		$gbk_str =~ s/<(.*?)\>|^\s+|\s+$|&nbsp;|&nbsp//g;
		$organism =~ s/<(.*?)\>|^\s+|\s+$|&nbsp;|&nbsp//g;
		$uniprot =~ s/<(.*?)\>|^\s+|\s+$|&nbsp;|&nbsp//g;
		
		$organism =~ s/\s+$//;
		
		my $protein_str='';
		
		my @array_id = split/\s+/,$protein;
		foreach my $id(@array_id)
		{
		    $id =~ s/\(|\)//g;
		    next if ($id !~ /\w+/);
		    $protein_str .= $id.';';
		}
		$protein_str = $protein if($protein_str eq '');
		
		$hash_org_protein_total{$organism}{$protein} = 1; 
		
		foreach my $gbk_prot(@gbk_protein)
		{
		    $gbk_prot =~ s/<(.*?)\>|^\s+|\s+$|&nbsp;|&nbsp|<b>|<\/b>//g;
		    next if ($gbk_prot !~ /\w+/);
		    
		    print OUTFILE "$family_id\t$protein_str\t$organism\t$ec\t$gbk_prot\t$uniprot\n";
		}#end foreach gbk_prot
	    }#foreach line;
	}#if data table;
    }#foreach table;
}#end parse
####################################################################################################################
