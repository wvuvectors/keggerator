#! /usr/bin/env perl -w
use strict;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "Usage: $progname\n";
$usage .=   "Extracts the taxonomy data from the fasta on STDIN and writes to STDOUT.\n";
$usage .=   "       [-d C] Replace space delimiters in taxonomy strings with character C instead.\n";
$usage .=   "\n";


my $delim;

while (@ARGV) {
  my $arg = shift;
  if ("$arg" eq "-h" or "$arg" eq "-help") {
  	die "$usage";
  } elsif ("$arg" eq "-d") {
  	defined ($delim=shift) or die "FATAL : Malformed -d argument!\n$usage\n";
  }
}


my $total  =0;
my $missing=0;

my %taxa = ();

while (my $line = <>) {
	chomp $line;
	next unless $line =~ /^>/;
	
	$total++;
	
	# grab the taxonomy data from the header line, if it exists
	my @a = split /\[/, "$line", -1;
	
	if (scalar @a > 1) {
		my $taxon = pop @a;
		$taxon =~ s/\]\s*$//;
		$taxon =~ s/ /$delim/gi if defined $delim;
		$taxa{$taxon} = $total unless defined $taxa{$taxon};
	} else {
		$missing++;
		#print STDERR "WARN  : Missing taxon for '$line'\n";
	}
}

print STDERR "WARN  : Missing $missing of $total taxa.\n" if $missing > 0;

foreach my $taxon (sort keys %taxa) {
	print "$taxon\n";
}

exit;

