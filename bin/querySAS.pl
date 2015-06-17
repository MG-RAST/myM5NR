#!/usr/bin/env perl

use strict;
use SAPserver; 
use Data::Dumper;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;

my @sources ;
my $verbose = 0;
my $debug   = 0;


my $md5 		= Digest::MD5->new;
my $sapObject 	= SAPserver->new();

GetOptions ( 
	"source=s" => \@sources , 
	'verbose+' => \$verbose ,
	'debug+'   => \$debug   ,
	);
	
@sources = split(/,/,join(',',@sources));

# id2genome_name mapping used globally 
my $genomes 	= $sapObject->all_genomes();

foreach my $source (@sources){
	
	if ($source eq 'SEED') {
		print STDERR "Retrieving SEED genomes and annotations.\n" if ($verbose) ;
		
		my $total = scalar (keys %$genomes)  ;
		my $current = 0;
		
		foreach my $g (sort { $genomes->{$a} cmp $genomes->{$b} }  keys(%$genomes)) {
		    #print "$g\t$genomes->{$g}\n";
			
			# Counting and being verbose
			$current++;
			my $start = time ;
			print STDERR "Processing Genome $g [$current/$total]\n" if($verbose > 1);
			
			# Get sequences and annotations 
			process_genomes( 'peg' , [$g] , $genomes );
			
			my $stop = time ;
			print STDERR "Time for Genome $g = " . ($stop - $start ) . " seconds.\n" if ($verbose > 1);
		}
		
	}
	elsif($source eq 'Subsystems'){
		print STDERR "Retrieving Subsystems and functional roles.\n" if ($verbose) ;
		my $subsystems 	= $sapObject->all_subsystems({-exclude => ['experimental']});
		
		my $total = scalar (keys %$subsystems)  ;
		my $current = 0;
		foreach my $ss (keys %$subsystems){
			$current++;
			print STDERR "$current :  $ss \n";
			my $ss_filename = $ss;
			$ss_filename =~ s/[^A-Za-z0-9\-\.]/_/g;
			$ss_filename = "subsystems_".$ss_filename;
			print STDERR "$ss -> ".$ss_filename."\n";
			if (-e $ss_filename) {
				print STDERR "Skip $ss , file ".$ss_filename." already exists\n";
				next;
			}
			

			my $ss_filename_part = $ss_filename.".part";
			
			my $retry = 0;
			my $success = 0;
			while (($retry < 5) && ($success==0)) {
				$retry++;
				
				unlink ($ss_filename_part) if (-e $ss_filename_part);
	
				
				open(my $ss_fh, '>', $ss_filename_part) or die "Could not open file '$ss_filename_part' $!";
				eval {
					
					my $start = time ;
					print STDERR "Processing Subsystem $ss [$current/$total]\n" if($verbose > 1);
					print Dumper $ss , $subsystems->{$ss} if ($debug);
			
					process_subsystem($ss_fh, $ss , $subsystems) ;
					my $stop = time ;
					print STDERR "Time for Subsystem $ss = " . ($stop - $start ) . " seconds.\n" if ($verbose > 1);
					close($ss_fh);
					$success = 1;
					
				};
				if ($@) {
					print STDERR "Processing Subsystem $ss failed [$current/$total]\n";
					print STDERR $@."\n";
					$success = 0;
					sleep 10;
					
				};
			}
			
				# file written sucessfully, rename it:
				if ( $success == 1 ) {
					rename($ss_filename_part, $ss_filename);
				} else {
					die $@;
				}
			
		}
		#TODO: loop to merge files ?

	}
	
}



exit;








sub process_subsystem{
	my ($ss_fh, $ss , $subsystems) = @_ ;
	
	
	# For subsystem classification ; level 1 and 2
	my @mapping = ( '' , '') ;
	
	$mapping[0] = ($subsystems->{$ss}->[1]->[0] | '' ) ;
	$mapping[1] = ($subsystems->{$ss}->[1]->[1] | '' ) ;
	
	
	my $ids_in_subsystems_args = {
		-subsystems => [$ss],
		-roleForm => 'full',
	};
	print STDERR "ids_in_subsystems_args: ".Dumper($ids_in_subsystems_args)."\n"
    my $subsysHash = $sapObject->ids_in_subsystems($ids_in_subsystems_args);
	

	foreach my $role (keys %{$subsysHash->{$ss}}){
		
		my $ids_to_sequences_args = {
			-ids => $subsysHash->{$ss}->{$role},
			-protein => 1,
		};
		print STDERR "ids_to_sequences_args: ".Dumper($ids_to_sequences_args)."\n"
		my $id2seq =  $sapObject->ids_to_sequences($ids_to_sequences_args);
		
		foreach my $fid (@{$subsysHash->{$ss}->{$role}}){
			
			my $organism_id = $fid =~ /fig\|(\d+\.\d)/ ; 
			
			print $ss_fh join ("\t" , seq2hexdigest( $id2seq->{$fid}) , $fid , $role , $genomes->{$fid} , 'Subsystems' , @mapping , $ss , $role , $id2seq->{$fid} ), "\n" ;
		}
	}				
}


sub process_genomes{
	my($type, $gids , $genomes) = @_;

    # print STDERR "Request @$genomes\n";
    my $fidHash = $sapObject->all_features(-ids => $gids, -type => $type);

    foreach my $gid (@$gids){
		foreach my $fid ( @{$fidHash->{$gid}} ){
				# print "$fid\n";
		}
		
		# list of feature IDs for genome
		my $ids = $fidHash->{$gid} ;
		#print Dumper $ids ;
#		exit;
		
		
		my $id2seq =  $sapObject->ids_to_sequences({
                            -ids => $ids,
                            -protein => 1,
						});
		# print Dumper $id2seq ;
		
		
	    my $results = $sapObject->ids_to_functions(-ids => $ids , -source => 'SEED');
	       # Loop through the genes.
	       for my $gene ( @$ids ) {
	           # Did we find a result?
	           my $role = $results->{$gene};
	           if (defined $role) {
	               # Yes, print it.
	               print join ("\t" , seq2hexdigest($id2seq->{$gene}) , $gene , $role , $genomes->{$gid} , 'SEED' ,$id2seq->{$gene} ) , "\n" ;
	           } else {
	               # No, emit a warning.
	               print STDERR "$gene was not found.\n";
	           }
	       }
		
		
	}
}


sub seq2hexdigest{
	my ($seq) = @_ ;
	
	$md5->reset ;
	$md5->add( uc($seq) );
	my $checksum = $md5->hexdigest;
	
	return $checksum ;
}
