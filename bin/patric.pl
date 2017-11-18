#!/usr/bin/perl

# patric
#
# extract md52id, md52seq.
#
#>fig|101571.178.peg.1|WL35_01530|   Proteins incorrectly called adenylate cyclase   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|101571.178.peg.2|WL35_01535|   Ferredoxin reductase   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|101571.178.peg.3|WL35_01540|   COG4339 metal-dependent phosphohydrolase, HD superfamily   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|101571.178.peg.4|WL35_01545|   hypothetical protein   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|101571.178.peg.5|   hypothetical protein   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]
#>fig|101571.178.peg.6|WL35_01550|   Putative outer membrane lipoprotein   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]

#
# folker@anl.gov


use Data::Dumper qw(Dumper);
use Digest::MD5 qw (md5_hex);
use strict;
use IO::Compress::Gzip qw(gzip $GzipError) ;
use IO::Uncompress::Gunzip;

# the main trick is to read the document record by record

my $dirname=shift @ARGV;

if ( $dirname eq "" )
{
  print STDERR "Usage: \tpatric.pl <DIRNAME>\n";
  exit 1;
}


open(my $md52id, '>',    'md52id_patric.txt') or die ;
open(my $md52seq, '>',   'md52seq_patric.txt') or die ;
open(my $md52func, '>',   'md52func_patric.txt') or die ;
open(my $id2tax, '>',   'id2tax_patric.txt') or die ;

# FOR EACH FILE IN THE DIRECTORY
opendir(DIR, $dirname) or die "Could not open $dirname\n";

while (my $filename = readdir(DIR)) {

  next if $filename !~ /.*\.faa/ ;
#  print "WORKING ON: $filename\n";

  open (my $fh1, '<', "$dirname/$filename") or die "Cannot open $dirname/$filename: $!\n" ;

      # ################# ################# ################# ################
      # ################# ################# ################# ################
      # ################# ################# ################# ################
      my $header=''; my $id; my $md5s=''; my $func='';   my $seq=''; my $tax;
      while (<$fh1>) {

        # for every header line
          if (/>/) {

            # if we already have a sequence ...  ## need to take care of last record
             if ($seq ne "") {    # found the next record

               $md5s = md5_hex($seq);

               # print the output
               print $md52id "$md5s\t$id\n";
               print $md52seq "$md5s\t$seq\n";
               print $md52func "$md5s\t$func\n";
               print $id2tax "$id\t$tax\n";

               # reset the values for the next record
               $id='';  $md5s='';  $func='';
             }


      #   >WP_003131952.1 30S ribosomal protein S18 [Lactococcus lactis]
          my $line = $_;
      #    $line =~ s/>//g;
      #>fig|101571.178.peg.5|   hypothetical protein   [Burkholderia ubonensis strain MSMB2104WGS | 101571.178]

          $id = (split( /\|/, $line))[1];
          $id= "fig|$id";
      #    print "ID\t$id\n";

          my $pos=index ($line, '[');
          my $len= length($id);
          $func = (split (/\[/, $line))[0];
          my $cut= rindex ($func,'|');
          $func = substr ($func, $cut+2);

          $tax = (split (/\[/, $line))[1];
          my $cut= rindex ($tax,'|');
          $tax = substr ($tax, 0, $cut);

          chomp $tax;
          chomp $func;
     #    print "TAX\t$tax\n";
  #       print "FUN\t$func\n";
              $seq = ""; # clear out old sequence
           }
         else {
            s/\s+//g; # remove whitespace
            $seq .= $_; # add sequence
         }
      }  # end of line

      close ($fh1);

} # of while readdir

closedir(DIR);
