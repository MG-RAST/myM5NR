#!/usr/bin/perl

# refseq
#
# extract md52id, md52seq.id2tax, md52tax
#
# >WP_027747122.1 S-(hydroxymethyl)mycothiol dehydrogenase [Streptomyces sp. CNH287]
#MAQEVRGVIAPGKDEPVRTETIVVPDPGPGEAVVEVRACGVCHTDLHYRQGGINDEFPFLLGHEAAGVVESVGEGVTEVA

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
  print STDERR "Usage: \trefseq.pl <DIRNAME>\n";
  exit 1;
}


open(my $md52id, '>',    'md52id.txt') or die ;
open(my $md52seq, '>',   'md52seq.txt') or die ;
open(my $md52func, '>',   'md52func.txt') or die ;
open(my $id2tax, '>',   'id2tax.txt') or die ;
open(my $id2func, '>',   'id2func.txt') or die ;
open(my $md52tax, '>',   'md52tax.txt') or die ;

# FOR EACH FILE IN THE DIRECTORY
opendir(DIR, $dirname) or die "Could not open $dirname\n";

while (my $filename = readdir(DIR)) {

  next if $filename !~ /.*\.gpff.gz/ ;
  print "WORKING ON: $filename\n";

  my $fh1 = new IO::Uncompress::Gunzip ("$dirname/$filename")
         or die "Cannot open $dirname/$filename': $!\n" ;

  # ################# ################# ################# ################
 # ################# ################# ################# ################
  # ################# ################# ################# ################

  # change EOL
  $/="//\n";

  while (defined (my $record = <$fh1>)) {

  my $id; my $md5; my $func=''; my $tax='';

      #  print $record;

      # find definition (might be multi line)
      if ($record =~ /\nDEFINITION\W+(.*)\[.*\]\./s )  {
          $func=$1;
          #print "FUNC:\t$func\n";
      }
      else {
        my $len= length($record);
        if ($len == 1 ) { next; }
      }


      #unset EOL
      $/='';

      foreach my $line (split /\n/ ,$record) {
         #  print $line."\n";

            if ($line =~ /^LOCUS\W+(\w+)/ ) {
              $id=$1;
            #  print "ID:\t$id\n";
              next;
            }

            if  ($line =~ /\W+.db_xref=\"taxon:(\d+)"+/) {
               $tax=$1;
               next;
            }



            # #if  ($line =~ /DEFINITION\W+(.+)\W+\[.*/) {
            # if  ($line =~ /^DEFINITION\W+/)    { # }(.+)\W+\[.*/) {
            #   $/="\].";
            #   $func= (split (/DEFINITION/ , $record))[1];
            #   print "FUNC:\t$func\n";
            #   $/="\n//";
            #   next;
            # }

          # parse sequence, generate md5 and write outfiles
          if  ($line =~ /^ORIGIN/) {

                # safety net
                if ($id eq '' || $tax eq '' || $func eq '') {
                #  print "ID:\t$id\nFUNC:\t$func\nTAX:\t$tax\n";
                #  print Dumper($record);
                  die "undefined value detected \n" ; }

                my @lines = split ('ORIGIN', $record);
                # parse sequence, generate md5 and write outfiles
                #	print Dumper(@lines);

                # split the record at the correct position to catch the sequences
                my $sequence = @lines[1];
                # join lines, remove the first list as well as the record separator
                $sequence =~ s/^(.*\n)//;
                $sequence =~ tr / \n\/\/[0-9]//ds;

                #print $sequence."\n\n\n";
                chomp $sequence;
                $sequence= lc ($sequence);
                $md5 = md5_hex($sequence);
                #print "MD5 $md5\n";

                print $md52seq "$md5\t$sequence\n";
                print $md52func "$md5\t$func\n";
                print $id2func "$id\t$func\n";
                print $id2tax "$id\t$tax\n";
                print $md52tax "$md5\t$tax\n";

                die "cannot find ID\n" if ( $id eq "");

                print $md52id "$md5\t$id\n" ;

                $id=''; $func=''; $tax=''; $md5='';
                next;
          }   # $line =~ ORIGIN

        } #foreach line

      # reset EOL  for next record
      $/="\n//";

      } # end of file


} # of while readdir
