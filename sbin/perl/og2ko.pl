#! /usr/bin/env perl -w
use strict;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname KIDFILE [options]\n";
$usage .=   "Extract lines from the ktransfer table file on STDIN that match the K numbers in KIDFILE and print to STDOUT.\n";
$usage .=   "       [-h]   Print this helpful information.\n";
$usage .=   "       [-c N] Find the K numbers in column N of KIDFILE [default: 0].\n";
$usage .=   "\n";


my $kidfile;
my $colnum = 0;

while (@ARGV) {
	my $arg=shift;
	if ($arg eq '-h' or $arg eq '-help') {
		die "$usage\n";
	} elsif ($arg eq '-c') {
		defined ($colnum=shift) or die "FATAL : Malformed -c argument.\n$usage\n";
	} else {
		$kidfile = $arg;
	}
}

$colnum =~ s/\D//g;

die "FATAL : A file of K numbers is required!\n$usage\n" unless defined $kidfile;
die "FATAL : The K number file ($kidfile) is not readable!\n$usage\n" unless -f "$kidfile";

# get the K numbers of interest and store them in a hash
my %kids  = ();
open my $idfh, "<", "$kidfile" or die "FATAL : Unable to open $kidfile for reading: $!\n";
while (my $line = <$idfh>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	
	my @a = split /\t/, "$line", -1;
	next if scalar @a <= $colnum;
	
	my $kidstr = splice @a, $colnum, 1;
	
	my @kid_list = split /\s*,\s*/, "$kidstr", -1;
	foreach my $kid (@kid_list) {
		$kids{$kid} = join("\t", @a);
	}
}
close $idfh;


# read in the ktransfer table and identify rows of interest
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	
	my @a = split /\t/, "$line", -1;
	next if scalar @a <= 2;
	
	my $ogid = $a[0];
	my @kid_list = split /\s*,\s*/, "$a[2]", -1;
	foreach my $kid (@kid_list) {
		if (defined $kids{$kid}) {
			print "$kid\t$ogid\t$kids{$kid}\n";
		}
	}
}


exit;


