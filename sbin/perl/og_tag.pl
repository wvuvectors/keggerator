#! /usr/bin/env perl -w
use strict;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname IDFILE [options]\n";
$usage .=   "Reads a transposed keggerator OG table from STDIN, groups the entries according to IDFILE, and writes to STDOUT. ";
$usage .=   "IDFILE is a mapping table of KOs (col 0), OGs (col 1), tags (col 2, optional), and groups (col 3, optional).\n";
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


my @ogs = ();

# read in IDFILE

open my $inFH, "<", "$idFile" or die "FATAL : IDFILE ($idFile) is not readable: $!\n$usage\n";
while (my $line = <$inFH>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;

	my @a = split /\t/, "$line", -1;
	my $ko = $a[0];
	my $ogid = $a[1];
	my %h = ("ogid" => $ogid, "tag" => $ogid, "group" => $ogid, "ko" => $ko);
	$h{"tag"}   = $a[2] if defined $a[2];
	$h{"group"} = $a[3] if defined $a[3];
	push @ogs, \%h;
}
close $inFH;


# loop through the input kreconstruct file
# lists taxa, one per line, and their membership across different OGs
# need to map each OG to its tag and add a row for the group (if applicable)

my @sorted_ogids = ();
my $count=0;
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
		
	if ($count == 0) {
		# replace OGs with tags
		my $locusline = "Locus";
		my $koline= "KO";
		my @a = split /\t/, $line, -1;
		shift @a;
		my $ogid = shift @a;
		my $pos = 0;
		while (defined $ogid) {
			push @sorted_ogids, $ogid;
			$locusline .= "\t$ogs[$pos]->{tag}";
			$koline    .= "\t$ogs[$pos]->{ko}";
			$pos++;
			$ogid = shift @a;
		}
		print "$koline\n$locusline\n$line\n";
		$count++;
	} elsif ($count == 1) {
		# replace the annotation line with group
		my $ogid = shift @sorted_ogids;
		$line = "Group";
		my $pos = 0;
		while (defined $ogid) {
			$line .= "\t$ogs[$pos]->{group}";
			$pos++;
			$ogid = shift @sorted_ogids;
		}
		print "$line\n";
		$count++;
	} elsif ($count == 2) {
		# remove the annotator id line
		$count++;
	} else {
		print "$line\n";
	}

}

exit;

