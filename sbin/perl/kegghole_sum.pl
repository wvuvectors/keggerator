#! /usr/bin/env perl -w
use strict;

use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname [options] OUTBASE\n";
$usage .=   "Takes the kegghole table on STDIN and creates several summary files:\n";
$usage .=   "   OUTBASE.by_group.kh.txt: counts of each KO by major taxonomic group.\n";
$usage .=   "   OUTBASE.by_genus.kh.txt: counts of each KO by genus.\n";
$usage .=   "   OUTBASE.complete.kh.txt: subset of genomes with 1+ members from every KO.\n";
$usage .=   "In addition, the following options can be used to write additional summary files.\n";
$usage .=   "        [-p PATT] Write all taxa that match the pattern seen in PATT to OUTBASE.matches.kh.txt.\n";
$usage .=   "                  PATT can be the name of a genus, or a series of 1s and 0s indicating presence or absence.\n";
$usage .=   "                  Alternatively, PATT can be a file with one pattern per line.\n";
$usage .=   "        [-i IF]    Ignore all KOs in file IF in comparative summaries (complete, genus).\n";
$usage .=   "\n";


my ($outbase, $pattern, $ignore_f);


while (@ARGV) {
  my $arg = shift;
  if ($arg eq '-h' or $arg eq '-help') {
  	die "$usage";
  } elsif ($arg eq '-p' or $arg eq '-pattern') {
  	defined ($pattern = shift) or die "FATAL : Malformed -p option.\n$usage\n";
  } elsif ($arg eq '-i' or $arg eq '-ignore') {
  	defined ($ignore_f = shift) or die "FATAL : Malformed -i option.\n$usage\n";
  } else {
  	$outbase = $arg;
  }
}

die "FATAL : No output file base name (OUTBASE) provided.\n$usage\n" unless defined $outbase;

my %data_by_taxon = ();

my %kos    = ();
my %groups = ();
my %genera = ();
#my %pways  = ();


# read the kegghole table from STDIN and store by taxon
my $hdr = 0;
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	my @cols = split /\t/, $line, -1;
	if ($hdr == 0) {
		# the header line; just parse out the KOs and store them in the kos hash
		for (my $i=3; $i<scalar(@cols); $i++) {
			next if $cols[$i] eq "";
			$kos{$cols[$i]} = $hdr;
			$hdr++;
		}
	} else {
		# a true data line
		my $group = shift @cols;
		my $genus = shift @cols;
		$genus = "Unk" if $genus eq "0";
		my $org   = shift @cols;
		
		$groups{$group} = 0 unless defined $groups{$group};
		$groups{$group} = $groups{$group} + 1;
		
		$genera{$genus} = 0 unless defined $genera{$genus};
		$genera{$genus} = $genera{$genus} + 1;
		
		$data_by_taxon{$org} = {"genus" => $genus, "group" => $group, "coverage" => []} unless defined $data_by_taxon{$org};
		my $t = 0;
		my $x_bin;
		for (my $i=0; $i<scalar(@cols); $i++) {
			unless ($cols[$i] eq "") {
				push(@{$data_by_taxon{$org}->{"coverage"}}, $cols[$i]);
				$t += $cols[$i];
				if (defined $x_bin) {
					$x_bin .= "$cols[$i]";
				} else {
					$x_bin  = "$cols[$i]";
				}
			}
		}
		$data_by_taxon{$org}->{"total"}   = $t;
		$data_by_taxon{$org}->{"pattern"} = $x_bin;
		$data_by_taxon{$org}->{"octkey"}  = oct("0b".$x_bin);
	}
}

#print Dumper(\%data_by_taxon);
#die;

# compile and print summary data
my @taxa_s   = sort keys %data_by_taxon;
my @kos_s    = sort { $kos{$a} <=> $kos{$b} } keys %kos;
my $ko_count = scalar keys %kos;
my $hdrline  = "#tax_group\tgenus\tkegg_org\t" . join("\t", @kos_s);

#print Dumper(\%kos);
#print STDERR "$ko_count\n";
#die;

open my $fha, ">", "$outbase.all.kh.txt" or die "$!";
print $fha "$hdrline\n";
foreach my $taxon (@taxa_s) {
	my $t = $data_by_taxon{$taxon};
	print $fha "$t->{group}\t$t->{genus}\t$taxon\t" . join("\t", @{$t->{"coverage"}}) . "\n";
}
close $fha;


open my $fhc, ">", "$outbase.complete.kh.txt" or die "$!";
print $fhc "$hdrline\n";
foreach my $taxon (@taxa_s) {
	my $t = $data_by_taxon{$taxon};
	next unless $t->{"total"} == $ko_count;
	print $fhc "$t->{group}\t$t->{genus}\t$taxon\t" . join("\t", @{$t->{"coverage"}}) . "\n";
}
close $fhc;


# read in the pattern or pattern file, if defined, and convert each to decimal equivalent (as key)
if (defined $pattern) {
	my $pname = "$pattern";
	my %patterns = ();
	my %matches  = ();
	
	if (-f $pattern) {
		my @a = split /\//, "$pname", -1;
		$pname = pop @a;
		$pname =~ s/\.txt//gi;
		open my $fhp, "<", "$pattern" or die "$!";
		while (my $line = <$fhp>) {
			chomp $line;
			unless ($line =~ /^\s*$/ or $line =~ /^#/) {
				my ($p, $label) = split /\t/, "$line", -1;
				$label = "$p" unless defined $label;
				my $octkey = oct("0b".$p);
				$patterns{$octkey} = $label;
			}
		}
		close $fhp;
	} else {
		my $octkey = oct("0b".$pattern);
		$patterns{$octkey} = $pattern;
	}
	
#	print Dumper(\%patterns);
#	die;
	
	#foreach my $taxon (@taxa_s) {
	#	my $t = $data_by_taxon{$taxon};
	#	next unless lc $t->{"genus"} eq lc $pattern;
	#	$matches{$t->{"octkey"}} = {} unless defined $matches{$t->{"octkey"}};
	#	$matches{$t->{"octkey"}}->{$taxon} = 1;
	#}
	
	open my $fhp, ">", "$outbase.m2_$pname.kh.txt" or die "$!";
	print $fhp "$hdrline\tpattern\tpattern_key\n";
	foreach my $t (@taxa_s) {
		my $taxon = $data_by_taxon{$t};
		my $octkey = $taxon->{"octkey"};
		if (defined $patterns{$octkey}) {
			print $fhp "$taxon->{group}\t$taxon->{genus}\t$t\t" . join("\t", @{$taxon->{"coverage"}}) . "\t$patterns{$octkey}\t$octkey\n";
		}
	}
	close $fhp;
}


exit;

