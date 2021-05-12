#! /usr/bin/env perl -w
use strict;

use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname OUTBASE\n";
$usage .=   "Takes the list of KO numbers on STDIN, retrieves the KEGG ortholog table html file, converts to tab-delimited ";
$usage .=   "format, and writes to STDOUT.\n";
$usage .=   "\n";


my $outbase;

while (@ARGV) {
  my $arg = shift;
  if ($arg eq '-h' or $arg eq '-help') {
  	die "$usage";
  } else {
  	$outbase = $arg;
  }
}

die "FATAL : No output file base name (OUTBASE) provided.\n$usage\n" unless defined $outbase;


# read the KO numbers from STDIN
my %komap = ();
my $count = 1;
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	my @a = split /\t/, "$line", -1;
	foreach my $ko (@a) {
		next if $ko =~ /^#/;
		$ko = trim($ko);
		unless (defined $komap{$ko} or $ko eq "") {
			$komap{$ko} = $count;
			$count++;
		}
	}
}

my @kos = sort { $komap{$a} <=> $komap{$b} } keys %komap;

# use wget to fetch the ortholog table (html) from KEGG
unless (-f "$outbase.kegg_table.html") {
	my $kostring = join "+", @kos;
	my $post = "against=bacteria&mode=all&orthology=$kostring";
	print STDERR "wget --quiet -O $outbase.kegg_table.html --post-data=\"$post\" https://www.kegg.jp/kegg-bin/view_ortholog_table\n";
	system("wget --quiet -O $outbase.kegg_table.html --post-data=\"$post\" https://www.kegg.jp/kegg-bin/view_ortholog_table");
}



# parse the html file into tab-delimited rows and write to STDOUT

my $startread = 0;
my $starthead = 0;
my $startrow  = 0;

open my $fh, "<", "$outbase.kegg_table.html" or die "$!";
while (my $line = <$fh>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	
	# open a table head read
	if ($line =~ /<thead>/) {
		$starthead = 1;
		next;
	}
	
	# close a table head read
	if ($line =~ /^<\/thead>/i) {
		$starthead = 0;
		$startread = 1;
		print "\n";
		next;
	}
	
	if ($starthead == 1 and $line =~ /^\s*<td.*?>(.*?)<\/td>\s*$/i) {
		my $cell = $1;
		if ($cell =~ /<a href=.+?>(.+?)<\/a><br.*?>(.+?)$/i) {
			print "$1 | $2\t";
		} else {
			print "$cell\t";
		}
		next;
	}	

	next unless $startread == 1;
	# open a new table row read
	if ($line =~ /^<tr>$/i) {
		$startrow = 1;
		next;
	}

	# shortcircuit unless an open table row read is present
	next unless $startrow == 1;
	
	# close a table row read
	if ($line =~ /^<\/tr>/i) {
		print "\n";
		$startrow  = 0;
		next;
	}
	
	# parse out the table cell contents
	if ($line =~ /^\s*<td.*?>(.*?)<\/td>\s*$/i) {
		my $cell = $1;
		if ($cell eq "") {
			print "0\t";
		} elsif ($cell =~ /<a href=(.+?)show_organism(.+?)>(.+?)</i) {
			print "$3\t";
		} elsif ($cell =~ /<a href/i) {
			print "1\t";
		} else {
			print "$cell\t";
		}
	}		
}
close $fh;

exit;


sub trim {
	my $str = shift;
	$str =~ s/^\s+//i;
	$str =~ s/\s+$//i;
	return $str;
}
