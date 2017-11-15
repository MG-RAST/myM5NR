#!/usr/bin/env perl

use strict;
use SAPserver; 
use Data::Dumper;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Getopt::Long;

my @sources ;
my $output_filename;
my $verbose = 0;
my $debug   = 0;

my $md5 		= Digest::MD5->new;
my $sapObject 	= SAPserver->new();

GetOptions ( 
	"source=s" => \@sources ,
	'output=s' => \$output_filename,
	'verbose+' => \$verbose ,
	'debug+'   => \$debug   ,
	);
	
@sources = split(/,/,join(',',@sources));


unless (defined $output_filename) {
	die "output_filename not defined.\n";
}

if ($output_filename eq "") {
	die "output_filename not defined.\n";
}


if ( -e $output_filename ) {
	die $output_filename." already exists.\n";
}

my $output_filename_part = $output_filename."_part";


unlink ($output_filename_part) if (-e $output_filename_part);

open my $out_fh, '>', $output_filename_part
	or die "Couldn't open ".$output_filename_part.": $!\n";


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
			process_genomes($out_fh, 'peg' , [$g] , $genomes );
			
			my $stop = time ;
			print STDERR "Time for Genome $g = " . ($stop - $start ) . " seconds.\n" if ($verbose > 1);
		}
		
	}
	elsif($source eq 'Subsystems'){
		print STDERR "Retrieving Subsystems and functional roles.\n" if ($verbose) ;
		my $subsystems 	= $sapObject->all_subsystems({-exclude => ['experimental']});
		
    open(File , ">subsystem.list") ;
    foreach my $ss (sort keys %$subsystems){
      print File "$ss\n";
    }
    close File ; 
    
		my $total = scalar (keys %$subsystems)  ;
		my $current = 0;
		foreach my $ss (sort keys %$subsystems){
			$current++;
			print STDERR "$current/$total :  $ss \n";
			my $ss_filename = $ss;
			$ss_filename =~ s/[^A-Za-z0-9\-\.]/_/g;
			$ss_filename = "subsystems_".$ss_filename;
			print STDERR "$ss -> ".$ss_filename."\n";
			if (-e $ss_filename) {
				print STDERR "Skip $ss , file ".$ss_filename." already exists\n";
        paste_file($out_fh, $ss_filename);
				next;
			}
			

			my $ss_filename_part = $ss_filename.".part";
			
			my $retry = 0;
			my $success = 0;
			my $debug = 0;
      
      # Set wait time for resume
      my $wait = 10 ;
      
			while (($retry < 10) && ($success==0)) {
				$retry++;
				
				if ($retry > 1) {
					$debug = 1;
				}
				
				
				unlink ($ss_filename_part) if (-e $ss_filename_part);
	
				
				open(my $ss_fh, '>', $ss_filename_part) or die "Could not open file '$ss_filename_part' $!";
				eval {
					
					my $start = time ;
					print STDERR "Processing Subsystem $ss [$current/$total]\n" if($verbose > 1);
					print Dumper $ss , $subsystems->{$ss} if ($debug);
			
					process_subsystem($ss_fh, $ss , $subsystems, $debug) ;
					my $stop = time ;
					print STDERR "Time for Subsystem $ss = " . ($stop - $start ) . " seconds.\n" if ($verbose > 1);
					close($ss_fh);
					$success = 1;
					
				};
				if ($@) {
					print STDERR "Processing Subsystem $ss failed [$current/$total]\n";
					print STDERR $@."\n";
					$success = 0;
					sleep $wait;
          $wait = $wait * 2 ;
          # Don't wait longer than 2 hours
          if ($wait >= 7200) {
            $wait = 7200 ;
          } 
					
				};
			}
			
			
				if ( $success == 1 ) {
					# file written sucessfully, rename it:
					rename($ss_filename_part, $ss_filename);
					
					paste_file($out_fh, $ss_filename);
					
				} else {
					die $@;
				}
			
		}
		#TODO: loop to merge files ?

	}
	
  else{
    print STDERR "Unkown source.\n" ;
    
  }
  
}

close($out_fh);


rename($output_filename_part, $output_filename);

exit;



sub paste_file {
	
	my ($out_fh, $ss_filename) = @_;
	
	# copy content to result file
	open my $in_fh, '<', $ss_filename
	or die "Couldn't open ".$ss_filename." for reading: $!\n";
	
	{
		local $/ = \65536; # read 64kb chunks
		while ( my $chunk = <$in_fh> ) { print $out_fh $chunk; }
	}
	close($in_fh);
	
	
}




sub process_subsystem{
	my ($ss_fh, $ss , $subsystems, $debug) = @_ ;
	
	
	# For subsystem classification ; level 1 and 2
	my @mapping = ( '' , '') ;
	
	$mapping[0] = ($subsystems->{$ss}->[1]->[0] | '' ) ;
	$mapping[1] = ($subsystems->{$ss}->[1]->[1] | '' ) ;
	
	
	my $ids_in_subsystems_args = {
		-subsystems => [$ss],
		-roleForm => 'full',
	};
	if ($debug > 0) {
		print STDERR "ids_in_subsystems_args: ".Dumper($ids_in_subsystems_args)."\n";
	}
    my $subsysHash = $sapObject->ids_in_subsystems($ids_in_subsystems_args);
	

	foreach my $role (keys %{$subsysHash->{$ss}}){
		
		my $ids_to_sequences_args = {
			-ids => $subsysHash->{$ss}->{$role},
			-protein => 1,
		};
		if ($debug > 0) {
			print STDERR "ids_to_sequences_args: ".Dumper($ids_to_sequences_args)."\n";
		}
		my $id2seq =  $sapObject->ids_to_sequences($ids_to_sequences_args);
		
		foreach my $fid (@{$subsysHash->{$ss}->{$role}}){
			
			my $organism_id = $fid =~ /fig\|(\d+\.\d)/ ; 
			
			print $ss_fh join ("\t" , seq2hexdigest( $id2seq->{$fid}) , $fid , $role , $genomes->{$fid} , 'Subsystems' , @mapping , $ss , $role , $id2seq->{$fid} ), "\n" ;
		}
	}				
}


sub process_genomes{
	my($out_fh, $type, $gids , $genomes) = @_;

    # print STDERR "Request @$genomes\n";
    my $fidHash = $sapObject->all_features(-ids => $gids, -type => $type);

    foreach my $gid (@$gids){
		#foreach my $fid ( @{$fidHash->{$gid}} ){
				# print "$fid\n";
		#}
		
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
	               print $out_fh join ("\t" , seq2hexdigest($id2seq->{$gene}) , $gene , $role , $genomes->{$gid} , 'SEED' ,$id2seq->{$gene} ) , "\n" ;
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
