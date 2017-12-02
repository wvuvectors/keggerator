#! /usr/bin/env perl -w
use strict;

use Data::Dumper;

my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname IDFILE [options]\n";
$usage .=   "Reads a transposed keggerator OG table from STDIN, sorts the columns according to IDFILE, and writes to STDOUT. ";
$usage .=   "IDFILE is a mapping table of KOs (col 0), locus tags (col 2, optional), and groups (col 3, optional).\n";
$usage .=   "\n";


my $idFile;


while (@ARGV) {
	my $arg=shift;
	if ($arg eq '-h' or $arg eq '-help') {
		die "$usage";
	} else {
		$idFile = $arg;
	}
}

die "FATAL : IDFILE is not defined.\n$usage\n" unless defined $idFile;
die "FATAL : IDFILE ($idFile) is not a readable file.\n$usage\n" unless -f $idFile;


my %ko_data     = ();
my @ordered_kos = ();

# read in IDFILE
open my $inFH, "<", "$idFile" or die "FATAL : IDFILE ($idFile) is not readable: $!\n$usage\n";
while (my $line = <$inFH>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;

	my @a = split /\t/, "$line", -1;
	my $ko    = $a[0];
	my $locus = $a[0];
	$locus = $a[1] if defined $a[1];
	
	$ko_data{$ko} = [];
	push @{$ko_data{$ko}}, $ko;
	push @{$ko_data{$ko}}, $locus;
	push @ordered_kos, $ko;
}
close $inFH;


# loop through the kreconstruct table
# lists taxa, one per line, and their membership across different OGs
# need to sort each column by its tag, as ordered in @ordered_kos

my @ko_by_col = ();
my @labels    = ();

my $row = 0;
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;

	my @a = split /\t/, $line, -1;
	push @labels, shift(@a);
	
	if ($row == 0) {
		my $ko = shift @a;
		while (defined $ko) {
			push @ko_by_col, $ko;
			$ko = shift @a;
		}
	} elsif ($row > 1) {
		my $col = 0;
		my $val = shift @a;
		while (defined $val) {
			my $ko = $ko_by_col[$col];
			push @{$ko_data{$ko}}, $val;
			$val = shift @a;
			$col++;
		}
	}
	$row++;
}

#print Dumper(\%ko_data);

# print the sorted data
for (my $i=0; $i<scalar(@labels); $i++) {
	print "$labels[$i]";
	foreach my $ko (@ordered_kos) {
		print "\t";
		print "$ko_data{$ko}->[$i]" if defined $ko_data{$ko}->[$i];
	}
	print "\n";
}

exit;

