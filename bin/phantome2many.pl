#!/usr/bin/perl

# phantome2
# no parameters, expects to be run from directory with the file
# all files created are two colum tables
#
# folker@anl.gov


# >fig|10756.2.peg.4 [Phage protein] [ACLAME_Phage_proteins_with_unknown_functions; Phage_cyanophage; Phage_experimental] [10756.2] [Bacillus phage phi29]
#MVQNDFVDSYDVTMLLQDDDGKQYYEYHKGLSLSDFEVLYGNTADEIIKLRLDKVL
#>fig|10756.2.peg.5 [involved in DNA replication] [Not in a subsystem] [10756.2] [Bacillus phage phi29]
#MGKIFDQEKRLEGTWKNSKWGNQGIIAPVDGDLKMIDLELEKKMTKLEHENKLMKNALYELSRMENNDYATWVIKVLFGGAPHGAK
#>fig|10756.2.peg.6 [DNA polymerase (EC 2.7.7.7), phage-associated] [Phage_replication; T4-like_phage_core_proteins] [10756.2] [Bacillus phage phi29]
#MPRKMYSCDFETTTKVEDCRVWAYGYMNIEDHSEYKIGNSLDEFMAWVLKVQADLYFHNLKFDGAFIINWLERNGFKWSADGLPNTYNTIISRMGQWYMIDICLGYKGKRKIHTVIYDSLKKLPFPVKKIAKDFKLTVLKGDIDYHKERPVG

use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;


# the main trick is to read the document record by record

my $filename="/tmp/phantome.data.gz";


my $fh1 = new IO::Uncompress::Gunzip ("$filename")
       or die "Cannot open '$filename': $!\n" ;

open(my $md52idphantome, '>', 'md52id_phantome.txt') or die ;
open(my $md5seq, '>', 'md52seq_phantome.txt') or die ;
open(my $phantome2func, '>', 'id2func_phantome.txt') or die ;
open(my $md5func, '>', 'md52func_phantome.txt') or die ;
open(my $phantome2tax, '>', 'id2tax_phantome.txt') or die ;
open(my $md5tax, '>', 'md52tax_phantome.txt') or die ;
open(my $phantome2subsystem, '>', 'phantome2subsystem.txt') or die ;
open(my $id2func_phantom , '>' , 'id2func_phantome.txt') or die ;

# ################# ################# ################# ################
# ################# ################# ################# ################
# ################# ################# ################# ################
my $header=''; my $id; my $md5s=''; my $func=''; my $subsys=''; my $taxid=''; my $taxname=''; my $seq='';
while (<$fh1>) {
  
  # for every header line
    if (/>/) {
  

      # if we already have a sequence ...  ## need to take care of last record
       if ($seq ne "") {    # found the next record
       
         $md5s = md5_hex($seq);
         
         # print the output
         print $md52idphantome "$md5s\t$id\n";
         print $md5seq "$md5s\t$seq\n";
         print $md5func "$md5s\t$func\n";
         print $id2func_phantom "$id\t$func\n";
 	       print $md5tax   "$md5s\t$taxid\n";
         print $phantome2tax "$id\t$taxid\n";
         print $phantome2subsystem "$id\t$subsys\n";
         # reset the values for the next record
         $id='';  $md5s='';  $func='';  $subsys='';  $taxid='';  $taxname='';   
       }              

# >fig|10756.2.peg.12 [Phage protein] [ACLAME_Phage_head; Phage_capsid_proteins] [10756.2] [Bacillus phage phi29]
#        my $line =~ s/\]// ;

my $line = $_;
  $line =~ s/>//g;
  $line =~ s/\]//g;
  
      my @header = split ('\[', $line);
      
      $id=@header[0];
      $func=@header[1]; 
      $subsys=@header[2];   # might be multiple needs unwrapping
      $taxid=@header[3]; 
      $taxname=@header[4];

  

      $seq = ""; # clear out old sequence
   }         
   else {    
      s/\s+//g; # remove whitespace
      $seq .= $_; # add sequence
   }         
}  # end of line  



close ($fh1);

