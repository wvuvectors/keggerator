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


my @ordered_kos = ();
my %ko2locus    = ();

# read in IDFILE
open my $inFH, "<", "$idFile" or die "FATAL : IDFILE ($idFile) is not readable: $!\n$usage\n";
while (my $line = <$inFH>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;

	my @a = split /\t/, "$line", -1;
	my $ko    = $a[0];
	my $locus = $a[0];
	$locus = $a[1] if defined $a[1];
	
	push @ordered_kos, $ko;
	$ko2locus{$ko} = $locus;
}
close $inFH;


# loop through the kreconstruct table
# lists taxa, one per line, and their membership across different OGs
# need to sort each column by its tag, as ordered in @ordered_kos
# also must take into account multiple OGs for a single K

my @data = ();
my $rowcount = 0;

while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	
	$rowcount++;
	
	my @a = split /\t/, $line, -1;
	
	for (my $i=0; $i<scalar(@a); $i++) {
		$data[$i] = [] unless defined $data[$i];
		push @{$data[$i]}, $a[$i];
	}
}

#print Dumper(\@data);
#die;


my %ko2col = ();
foreach my $ko (@ordered_kos) {
	for (my $i=1; $i<scalar(@data); $i++) {
		if ("$ko" eq "$data[$i]->[0]") {
			$ko2col{$ko} = [] unless defined $ko2col{$ko};
			push @{$ko2col{$ko}}, $i;
		}
	}
}

#print Dumper(\%ko2col);
#die;


# print the sorted data
for (my $i=0; $i<$rowcount; $i++) {
	print "$data[0]->[$i]";
	foreach my $ko (@ordered_kos) {
		if (defined $ko2col{$ko}) {
			foreach my $col (@{$ko2col{$ko}}) {
				print "\t$data[$col]->[$i]";
			}
		} else {
			print "\t";
			print "$ko" if $i == 0;
			print "$ko2locus{$ko}" if $i == 1;
		}
	}
	print "\n";
}

exit;

