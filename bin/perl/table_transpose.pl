#! /usr/bin/perl -w

use strict;

my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname [options]\n";
$usage .=   "Transposes the table on STDIN (swaps rows and cols) and writes to STDOUT.\n";
$usage .=   "\n";


while (@ARGV) {
  my $arg = shift;
  if ($arg eq '-h' or $arg eq '-help') {
		die $usage;
	}
}

my @transposed=();
while (<>) {
	chomp;
	next if /^\s*$/;
	
	my $i=0;
	foreach my $val (split /\t/) {
		$transposed[$i]=[] unless defined $transposed[$i];
		push @{$transposed[$i]}, $val;
		$i++;
	}
}

foreach my $row (@transposed) {
	print join("\t", @$row) . "\n";
}

exit;


