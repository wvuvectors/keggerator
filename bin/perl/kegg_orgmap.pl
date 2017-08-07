#! /usr/bin/env perl -w
use strict;

use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname\n";
$usage .=   "Retrieve the latest list of genome identifiers from KEGG, map to genus and species, and output in tdf to STDOUT.\n";
$usage .=   "\n";


while (@ARGV) {
  my $arg = shift;
  if ($arg eq '-h' or $arg eq '-help') {
  	die "$usage";
  }
}

my %orgmap = ();


# use wget to fetch the genome map table (html) from KEGG
my $url = "http://www.kegg.jp/kegg/catalog/org_list.html";
#print STDERR "wget --quiet \"$url\"\n";
#my $htmlstr = `wget --quiet \"$url\"`;

print STDERR "curl \"$url\"\n";
my $htmlstr = `curl \"$url\"`;
print STDERR "html back: " . length($htmlstr) . "\n";

$htmlstr =~ s/\n//gi;

#print "$htmlstr\n";
#die;

my @groups = ();

# parse the html table rows into array
while ($htmlstr =~ /<tr align=center>(.+?)<\/tr>/gi) {
	#print "$1\n";
	#die;
	my @cells = split /<\/td>/, $1, -1;
	next unless scalar @cells > 2;
	
	my ($key, $linn, $common);
	my $foundgrps = 0;
	
	foreach my $cell (@cells) {
		if ($cell =~ /show_organism\?category=(.+?)\'>/i) {
			@groups = () if $foundgrps == 0;
			$foundgrps++;
			push @groups, $1;
		} elsif ($cell =~ /show_organism\?org=(.+?)'>/i) {
			$key = $1;
		} elsif ($cell =~ /www_bfind\?.+?'>(.+?)<\/a>/i) {
			$linn = trim($1);
		}
	}
	
	if (defined $key and defined $linn) {
		$orgmap{$key} = {"linnean" => $linn, "groups" => []};
		foreach my $group (@groups) {
			push @{$orgmap{$key}->{"groups"}}, $group;
		}
	}
	
}

# output map to tab-delim format

print "#korg\ttaxon\tgroup_broad\tgroup_mid\tgroup_narrow\n";
foreach my $key (sort keys %orgmap) {
	print "$key\t$orgmap{$key}->{linnean}\t";
	print join("\t", @{$orgmap{$key}->{"groups"}});
	print "\n";
}

exit;


sub trim {
	my $str = shift;
	$str =~ s/^\s+//i;
	$str =~ s/\s+$//i;
	return $str;
}
