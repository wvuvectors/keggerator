#! /usr/bin/env perl -w
use strict;

use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname KIDFILE [options]\n";
$usage .=   "Extract entries from the metaOGRE OG-KO catalog file on STDIN that match the KEGG map, module, or brite ids ";
$usage .=   "in KIDFILE, and print them to STDOUT.\n";
$usage .=   "       [-h]    Print this helpful information.\n";
$usage .=   "       [-g TF] Append the OG heatmap rows from OG table file TF to the output.\n";
$usage .=   "       [-og]   Print one row for every OG instead of one row for every KO. This may lead to rows with duplicate KOs.\n";
$usage .=   "\n";


my ($idfile, $og_tablef);
my $print_by_og = 0;

while (@ARGV) {
	my $arg=shift;
	if ($arg eq '-h' or $arg eq '-help') {
		die "$usage\n";
	} elsif ($arg eq '-g') {
		defined ($og_tablef = shift) or die "FATAL : Malformed -g argument.\n$usage\n";
	} elsif ($arg eq '-og') {
		$print_by_og = 1;
	} else {
		$idfile = $arg;
	}
}

die "FATAL : A file of KEGG ids is required!\n$usage\n" unless defined $idfile;
die "FATAL : The KEGG id file ($idfile) is not readable!\n$usage\n" unless -f "$idfile";

die "FATAL : The OG table file ($og_tablef) is not a readable file!\n$usage\n" if defined $og_tablef and ! -f "$og_tablef";


# get the KEGG map, module, or brite ids of interest and store them in a hash
my %kids  = ();
my %by_og = ();
my %by_ko = ();
open my $idfh, "<", "$idfile" or die "FATAL : Unable to open $idfile for reading: $!\n";
while (<$idfh>) {
	chomp;
	next if /^\s*$/ or /^#/;
	$kids{$_} = 1;
}
close $idfh;

my @kidarr = keys %kids;

#print Dumper(\%kids);
#die;

# read in the OG-KO catalog file and extract rows of interest
while (<>) {
	chomp;
	next if /^\s*$/ or /^#/;
	
	my @a = split /\t/, "$_", -1;
	if (scalar @a < 8) {
		print STDERR "WARN  : $_ has less than required number of columns. skipped.\n";
		next;
	}
	
	my $og   = "$a[0]";
	$og  = "ORPHAN | $a[1]" if "orphan" eq lc "$og";
	
	my $ko   = "$a[2]";
	my $prod = "$a[4]";
	my $ann  = "$a[5]\t$a[6]\t$a[7]";
	my $tax  = "$a[3]";
	
	
	foreach my $kid (@kidarr) {
		if ($ann =~ /$kid/i) {
			$by_og{$og} = {} unless defined $by_og{$og};
			$by_og{$og}->{"$ko"} = {"tax" => "$tax", "ann" => "$ann"};
			
			$by_ko{$ko} = {"ogids" => {}, "ogs" => [], "tax" => [], "prod" => [], "ann" => "$ann"} unless defined $by_ko{$ko};
			unless (defined $by_ko{$ko}->{"ogids"}->{$og}) {
				$by_ko{$ko}->{"ogids"}->{$og} = 1;
				push @{$by_ko{$ko}->{"ogs"}}, $og;
				push @{$by_ko{$ko}->{"tax"}}, $tax;
				push @{$by_ko{$ko}->{"prod"}}, $prod;
			}
		}
	}
}

#print Dumper(\%by_ko);
#die;

my @taxrow = ();
my %taxmap = ();

if (defined $og_tablef) {

	# read through OG table file and get heatmap entries
	# store them in the by_og and by_ko hashes
	my %og_rows = ();
	my $count = 0;
	open my $tfh, "<", "$og_tablef" or die "FATAL : Unable to open $og_tablef for reading: $!\n";
	while (<$tfh>) {
		chomp;
		next if /^\s*$/ or /^#/;
		my ($og, $ann, $aid, $row) = split /\t/, "$_", 4;
		my @heatmap = split /\t/, "$row";
		if ($count == 0) {
			@taxrow = @heatmap;
			for (my $i=0; $i < scalar(@taxrow); $i++) {
				$taxmap{$taxrow[$i]} = $i;
			}
		} else {
			foreach my $ko (keys %{$by_og{$og}}) {
				$by_og{$og}->{"$ko"}->{"heatmap"} = \@heatmap;
				if (defined $by_ko{$ko}->{"heatmap"}) {
					for (my $i=0; $i < scalar(@{$by_ko{$ko}->{"heatmap"}}); $i++) {
						$by_ko{$ko}->{"heatmap"}->[$i] = $by_ko{$ko}->{"heatmap"}->[$i] + $heatmap[$i] unless $heatmap[$i] eq "";
					}
				} else {
					$by_ko{$ko}->{"heatmap"} = \@heatmap;
				}
			}
		}
		$count++;
	}
	close $tfh;
	
	# add ORPHAN entries into the by_ko heatmaps where appropriate!
	foreach my $ko (keys %by_ko) {
		my @ogs = @{$by_ko{$ko}->{"ogs"}};
		for (my $i=0; $i < scalar(@ogs); $i++) {
			if (index(lc $ogs[$i], "orphan") != -1) {
				my $tax = $by_ko{$ko}->{"tax"}->[$i];
				my $pos = $taxmap{$tax};
				unless (defined $by_ko{$ko}->{"heatmap"}) {
					$by_ko{$ko}->{"heatmap"} = [];
					for (my $j=0; $j<scalar(@taxrow); $j++) {
						$by_ko{$ko}->{"heatmap"}->[$j] = 0;
					}
				}
				$by_ko{$ko}->{"heatmap"}->[$pos] = $by_ko{$ko}->{"heatmap"}->[$pos] + 1;
			}
		}
	}
	
}

#print Dumper(\%taxmap);
#die;

print "#KO\tOG\tproduct\tmodules\tpathways\tbrites";
if (scalar @taxrow > 0) {
	print "\t";
	print join("\t", @taxrow);
}
print "\n";

if ($print_by_og) {
	foreach my $og (sort keys %by_og) {
		foreach my $ko (sort {$a cmp $b} keys %{$by_og{$og}}) {
			print "$ko\t$og\t" . join(", ", @{$by_og{$og}->{$ko}->{"prod"}}) . "\t$by_og{$og}->{$ko}->{ann}";
			if (scalar @taxrow > 0) {
				print "\t";
				print join("\t", @{$by_og{$og}->{$ko}->{"heatmap"}});
			}
			print "\n";
		}
	}
} else {
	foreach my $ko (sort {$a cmp $b} keys %by_ko) {
		my %sum = %{$by_ko{$ko}};
		print "$ko\t" . join(", ", @{$sum{"ogs"}}) . "\t" . join(", ", @{$sum{"prod"}}) . "\t$sum{ann}";
		if (scalar @taxrow > 0) {
			print "\t";
			print join("\t", @{$sum{"heatmap"}});
		}
		print "\n";
	}
}


exit;


