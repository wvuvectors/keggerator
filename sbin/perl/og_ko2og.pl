#! /usr/bin/env perl -w
use strict;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname OGFILE [options]\n";
$usage .=   "Maps KO entries in the kcompile table on STDIN to OGs in OGFILE and writes to STDOUT. ";
$usage .=   "Expects standard ogre (orthoMCL) input format (the .end file).\n";
$usage .=   "       [-h] Print this helpful information.\n";
$usage .=   "\n";


my $ogfile;


while (@ARGV) {
	my $arg=shift;
	if ($arg eq '-h' or $arg eq '-help') {
		die "$usage\n";
	} else {
		$ogfile = $arg;
	}
}

die "FATAL : An ogre (orthoMCL) output (.end) file is required, but was not provided.\n$usage\n" unless defined $ogfile;
die "FATAL : $ogfile (the ogre/orthoMCL output file) is not a readable file.\n$usage\n" unless -f "$ogfile";


my %members = ();
my %ogs     = ();

# loop through the input OG file
# lists OGs, one per line, with all genes and their taxa
open my $ogfh, "<", "$ogfile" or die "FATAL : Unable to open $ogfile for reading: $!\n";
while (my $line = <$ogfh>) {
	chomp $line;
	next if $line =~ /^\s*$/;
	
	my ($ogid, $memberstr) = split /\t/, $line, -1;
	$ogid =~ s/^(.+?)\s.*$/$1/gi;
	$ogid =~ s/\D//g;
	$ogs{$ogid} = {} unless defined $ogs{$ogid};

	while ($memberstr =~ /\s(.+?)\((.+?)\)/gi) {
		my $mid = $1;
		my $tax = $2;
		
		$ogs{$ogid}->{$mid} = 1;
		
		$members{$mid} = {} unless defined $members{$mid};
		$members{$mid}->{'og'}  = $ogid;
		$members{$mid}->{'tax'} = $tax;
	}
}
close $ogfh;


if (scalar keys %members == 0) {
	print STDERR "WARN  : No OGs found.\n";
	exit;
}


my %og_labels = ();
my %orphans   = ();

# loop through the kcompile table, one member per line
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	my ($id, $organism, $product, $ko, $modules, $pathways, $brites) = split /\t/, $line, -1;

	$members{$id} = {} unless defined $members{$id};
	$members{$id}->{'ko'} = $ko;
		
	if (defined $members{$id}->{'og'}) {
		my $ogid = $members{$id}->{'og'};
		$og_labels{$ogid} = {"ko" => {}, "product" => {}, "organism" => {}, "modules" => {}, "pathways" => {}, "brites" => {}} unless defined $og_labels{$ogid};
		
		$og_labels{$ogid}->{"ko"}->{$ko}             = 0 unless defined $og_labels{$ogid}->{"ko"}->{$ko};
		$og_labels{$ogid}->{"ko"}->{$ko}             = 1 + $og_labels{$ogid}->{"ko"}->{$ko};
		
		$og_labels{$ogid}->{"organism"}->{$organism} = 0 unless defined $og_labels{$ogid}->{"organism"}->{$organism};
		$og_labels{$ogid}->{"organism"}->{$organism} = 1 + $og_labels{$ogid}->{"organism"}->{$organism};
		
		$og_labels{$ogid}->{"product"}->{$product}   = 0 unless defined $og_labels{$ogid}->{"product"}->{$product};
		$og_labels{$ogid}->{"product"}->{$product}   = 1 + $og_labels{$ogid}->{"product"}->{$product};
		
		$og_labels{$ogid}->{"modules"}->{$modules}   = 0 unless defined $og_labels{$ogid}->{"modules"}->{$modules};
		$og_labels{$ogid}->{"modules"}->{$modules}   = 1 + $og_labels{$ogid}->{"modules"}->{$modules};
		
		$og_labels{$ogid}->{"pathways"}->{$pathways} = 0 unless defined $og_labels{$ogid}->{"pathways"}->{$pathways};
		$og_labels{$ogid}->{"pathways"}->{$pathways} = 1 + $og_labels{$ogid}->{"pathways"}->{$pathways};
		
		$og_labels{$ogid}->{"brites"}->{$brites}     = 0 unless defined $og_labels{$ogid}->{"brites"}->{$brites};
		$og_labels{$ogid}->{"brites"}->{$brites}     = 1 + $og_labels{$ogid}->{"brites"}->{$brites};
		
	} else {
		$orphans{$id} = {} unless defined $orphans{$id};
		
		$orphans{$id}->{"ko"} = $ko;
		$orphans{$id}->{"organism"} = $organism;
		$orphans{$id}->{"product"}  = $product;
		$orphans{$id}->{"modules"}  = $modules;
		$orphans{$id}->{"pathways"} = $pathways;
		$orphans{$id}->{"brites"}   = $brites;
	}
}


# write KO-to-OG map
print "#ogid\ttotal_members\tunique_kos\tunique_orgs\tproduct\tmodules\tpathways\tbrites\n";
foreach my $ogid (sort {$a <=> $b} keys %og_labels) {
	my $ct_mem = scalar keys %{$ogs{$ogid}};
	my $ct_ko  = summ($og_labels{$ogid}->{"ko"});

	my @a = ();
	foreach my $ko (keys %{$og_labels{$ogid}->{"ko"}}) {
		next if "" eq "$ko";
		push @a, $ko;
	}
	my $ko_list = join "|", @a;

	my $uniq_org = scalar keys %{$og_labels{$ogid}->{"organism"}};
	my $product  = get_rep($og_labels{$ogid}->{"product"});
	
	if ($ct_ko == 0) {
		print "$ogid\t$ct_mem\t\t$uniq_org\t$product->{ids}\t\t\t\n";
	} else {
		my $uniq_ko  = scalar keys %{$og_labels{$ogid}->{"ko"}};

		my $module   = get_rep($og_labels{$ogid}->{"modules"});
		my $pathway  = get_rep($og_labels{$ogid}->{"pathways"});
		my $brite    = get_rep($og_labels{$ogid}->{"brites"});
	
		print "$ogid\t$ct_mem\t$ko_list\t$uniq_org\t$product->{ids}\t$module->{ids}\t$pathway->{ids}\t$brite->{ids}\n";
	}
}

foreach my $id (sort {$orphans{$a}->{"organism"} cmp $orphans{$b}->{"organism"} || $orphans{$b}->{"ko"} cmp $orphans{$a}->{"ko"}} keys %orphans) {
	my $ko   = $orphans{$id}->{"ko"};
	my $org  = $orphans{$id}->{"organism"};
	print "ORPHAN\t$id\t$ko\t$org\t$orphans{$id}->{product}\t$orphans{$id}->{modules}\t$orphans{$id}->{pathways}\t$orphans{$id}->{brites}\n";
}
exit;



sub summ {
	my $list_ref = shift;
	
	my $total = 0;
	foreach my $id (keys %{$list_ref}) {
		next if "" eq "$id";
		$total += $list_ref->{$id};
	}
	return $total;
}


sub get_rep {
	my $list_ref = shift;
	
	my ($max, %maxids) = (0, ());
	foreach my $id (keys %{$list_ref}) {
		next if "" eq "$id";
		my $ct = $list_ref->{$id};
		if ($ct == $max) {
			$maxids{$id} = 1;
		} elsif ($ct > $max) {
			$max    = $ct;
			%maxids = ($id => 1);
		}
	}
	
	my %ret = ("support" => $max, "ids" => join("; ", keys %maxids));
	return \%ret;
	
}




