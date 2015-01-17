use strict;
use SAPserver; 
use Data::Dumper;

my $sapObject = SAPserver->new();
my $genomes = $sapObject->all_genomes();

foreach my $g (sort { $genomes->{$a} cmp $genomes->{$b} }  keys(%$genomes)) {
    #print "$g\t$genomes->{$g}\n";
	
	process_genomes( 'peg' , [$g] , $genomes );
}



sub process_genomes{
	my($type, $gids , $genomes) = @_;

    # print STDERR "Request @$genomes\n";
    my $fidHash = $sapObject->all_features(-ids => $gids, -type => $type);

    foreach my $gid (@$gids){
		foreach my $fid ( @{$fidHash->{$gid}} ){
				# print "$fid\n";
		}
		
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
	               print join "\t" , $genomes->{$gid} , $gene , $role , $id2seq->{$gene} , "\n" ;
	           } else {
	               # No, emit a warning.
	               print STDERR "$gene was not found.\n";
	           }
	       }
		
		
	}
}