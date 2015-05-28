#!/usr/bin/env perl

use warnings ;
use strict ;
use DB_File ;
use Data::Dumper;
use Getopt::Long;


my @files ; # source files for import
my %hash  ; # DB Hash

my $filename = "myM5NR.tmp.berkeleyDB" ;
 
 
my $verbose = 0 ;
my $debug 	= 0 ;

GetOptions ( 
	"load=s" => \@files , 
	"dbname=s" => \$filename ,
	'verbose+' => \$verbose ,
	'debug+'   => \$debug   ,
	);
	
# Create new DB , delete old file	
unlink $filename ;

# Initialize DB
my $db = tie %hash, 'DB_File', $filename, O_CREAT|O_RDWR, 0666, $DB_HASH or die "Cannot open $filename: $!\n" ;

# Install DBM Filters


$hash{"abc"} = "def" ;
my $a = $hash{"ABC"} ;
# ...
print join "\t" , ($a || 'undef') , ($hash{"abc"} || 'undef') , "\n" ;

foreach my $f (@files) {
	
	if(-f $f){
		
		open(FILE , $f) or die "Can't open file $f and did not check properly!\n" ;
		
		while(my $line = <FILE>){
			chomp $line ;
			my ($md5 , $id , $func , $org , $source , @remainder) = split "\t" , $line ;
			
			unless($id){
				print STDERR $line , "\n" ;
				print STDERR $md5 , "\n";
				next;
			}

			my $value = join "\t" ,  $id , $func , $org , $source ;
			$value .= "\n" ;

			if ($hash{$md5}){	
				$hash{$md5} = $hash{$md5} . $value  ;
				print STDERR $hash{$md5} if ($debug);
			}
			else{
				$hash{$md5} = $value ;
				print STDERR $hash{$md5} if ($debug) ;
				
			} 
		}
		
	}
	else{
		print STDERR "Not a valid file $f!\n";
	}
	
}

print $hash{'f30d1c4cfb8f6d5ca821d178b70bcce6'} , "\n" ;
print Dumper split "\n" , $hash{'f30d1c4cfb8f6d5ca821d178b70bcce6'} ;

undef $db ;
untie %hash ;
