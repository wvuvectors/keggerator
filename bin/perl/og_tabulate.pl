#! /usr/bin/perl -w

use strict;

use List::Util qw(max);
use Statistics::Basic qw(:all);

use Data::Dumper;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname [options]\n";
$usage .=   "Tabulates the orthoMCL/FastOrtho file on STDIN and writes to STDOUT.\n";
$usage .=   "       [-s F] Sort taxa according to entries in file F (one per line).\n";
$usage .=   "       [-a T A] Annotate OGs with protein annotations from a \n";
$usage .=   "                file T of prioritized taxa. Look for \n";
$usage .=   "                the annotations in fasta file A.\n";
$usage .=   "       [-f]   Use full id string as annotation ID instead of parsing the ref.\n";
$usage .=   "       [-v L|I|C] Report protein (L)engths, (I)Ds, or (C)ounts (default) in each cell of the table.\n";
$usage .=   "\n";


my @sorted_taxa = ();
my @annotators  = ();
my $annfile;
my $parse_ref   = 1;
my $cell        = "c";
my %accepted_cells = ("l" => 1, "i" => 1, "c" => 1);

while (@ARGV) {
	my $arg=shift;
	if ($arg eq '-h' or $arg eq '-help') {
		die "$usage";
	} elsif ($arg eq '-s' or $arg eq '-sort' or $arg eq '-sortfile') {
		defined (my $sortfile=shift) or die "FATAL : Malformed -s option.\n$usage\n";
		open my $sf, "<", "$sortfile" or die "FATAL : unable to open $sortfile for reading.\n$usage\n";
		while (<$sf>) {
			chomp;
			next if /^\s*$/ or /^#/;
			s/ /_/gi;
			s/"//gi;
			s/'//gi;
			push @sorted_taxa, "$_";
		}
		close $sf;
	} elsif ($arg eq '-a' or $arg eq '-ann' or $arg eq '-annotate') {
		if (defined $ARGV[0] and substr($ARGV[0],0,1) ne '-') {
			defined (my $tlist=shift) or die "FATAL : Malformed -a option (taxon file).\n$usage\n";
			if (-f "$tlist") {
				open my $tf, "<", "$tlist" or die "FATAL : Unable to open $tlist for reading.\n$usage\n";
				while (<$tf>) {
					chomp;
					next if /^\s*$/ or /^#/;
					s/ /_/gi;
					s/"//gi;
					s/'//gi;
					push @annotators, "$_";
				}
				close $tf;
			} else {
				@annotators=split /,\s*/, $tlist;
			}
		}
		if (defined $ARGV[0] and substr($ARGV[0],0,1) ne '-') {
			defined ($annfile=shift) or die "FATAL : Malformed -a option (annotate file).\n$usage\n";
		}
	} elsif ($arg eq '-f' or $arg eq '-full') {
		$parse_ref = 0;
	} elsif ($arg eq '-v' or $arg eq '-val' or $arg eq '-vals' or $arg eq "-values") {
		defined ($cell = shift) or die "FATAL : Malformed -v option.\n$usage\n";
		$cell = lc $cell;
		$cell =~ s/^(.).*$/$1/gi unless $cell eq "lp";
		die "FATAL : Malformed -v option.\n$usage\n" unless defined $accepted_cells{$cell};
	}
}


my @sorted_ogids = ();
my %taxa_by_og   = ();
my %ann_by_og    = ();
my %all_taxa     = ();


# loop through the input file from OrthoMCL/FastOrtho
# lists OGs, one per line, with all genes and their taxa
while (my $line = <>) {
	chomp $line;
	next if $line =~ /^\s*$/ or $line =~ /^#/;
	
	my ($ogid, $members) = split /\t/, $line;
	$ogid =~ s/^(.+?)\s.*$/$1/gi;
	$ogid =~ s/ORTHOMCL(\S+?)/$1/gi;
	
	# store the input order of OGs in an array for proper retrieval
	push @sorted_ogids, $ogid;
	
	# loop over the protein ids and associated taxa that comprise this OG
	my $first_tax;
	while ($members =~ /\s(.+?)\((.+?)\)/gi) {
		my $pid = $1;
		my $tax = $2;
		$tax =~ s/ /_/gi;
		#$tax =~ s/'//gi;
		$tax =~ s/"/'/gi;
		
		# record this taxon in the list of all taxa
		$all_taxa{$tax} = 1;
		
		# associate this taxon and its protein id with this OG
		$taxa_by_og{$ogid}->{$tax} = {} unless defined $taxa_by_og{$ogid}->{$tax};
		$taxa_by_og{$ogid}->{$tax}->{$pid} = 1;
		
		# log the first taxon encountered, for later default annotation use
		$first_tax = $tax unless defined $first_tax;
	}
	$first_tax = "N/A" unless defined $first_tax;
	
	
	# grab a protein id to annotate the entire OG
	my $ann=0;
	for (my $i=0; $i<scalar(@annotators); $i++) {
		my $anntax = $annotators[$i];
		if (defined $taxa_by_og{$ogid}->{$anntax}) {
			$ann_by_og{$ogid} = $taxa_by_og{$ogid}->{$anntax};
			$ann = 1;
			last;
		}
	}
	
	# by default, use the id from the first taxon in the OG
	$ann_by_og{$ogid} = $taxa_by_og{$ogid}->{$first_tax} unless $ann;
	
}

#print Dumper(\%taxa_by_og);
#exit;

# lookup annotations
my %protein_info_by_pid = ();
my $pid;
my $seq = "";

if (defined $annfile) {
	open my $fh, "<", "$annfile" or die "$!";
	while (my $line = <$fh>) {
		chomp $line;

		if ($line =~ /^>/) {
			
			if (defined $pid) {
				my $len = length $seq;
				$protein_info_by_pid{$pid}->{"length"} = $len;
				$seq = "";
			}
			
			$line =~ s/^>//;
			my ($id, $ann) = split /\s+/, $line, 2;
			my @a = split /\[/, $ann;
			if (scalar @a > 1) {
				pop @a;
				$ann = join "[", @a;
			}
			$ann = trim($ann);
			$protein_info_by_pid{$id} = {"ann" => $ann, "length" => 0};
			$pid = $id;
		} else {
			$seq .= "$line";
		}
	}
	close $fh;

	my $len = length $seq;
	$protein_info_by_pid{$pid}->{"length"} = $len;
}


# default taxon sort order is alphanumeric
# ignored if the array of sorted taxa was pre-populated from user input
@sorted_taxa= sort keys %all_taxa unless scalar @sorted_taxa > 0;

print "OG\tAnnotation\tAnnotator ID\tLength (Max)\tLength (Mean)\tLength (SD)\tLength (Median)\tLength (Mode)\t" . join("\t", @sorted_taxa) . "\n";

# loop over the OG ids
# default OG sort order is by order in the ogre .end file used as input
# this was recorded in the array @sorted_ogids
foreach my $ogid (@sorted_ogids) {
	my ($ann_id, $ann_str);
	
	if ($ogid < 0) {
		print "$ogid\t-\t-\t0\t0\t0\t0\t0\t";
		my @a = (0) x scalar(@sorted_taxa);
		print join("\t", @a) . "\n";
		next;
	}
	
	my @lengths    = ();
	my @printables = ();
	
	# get the annotation string and annotator id from the ann_by_og hash 
	foreach my $pid (keys %{$ann_by_og{$ogid}}) {
		last if defined $ann_id;
		
		$ann_id = $pid;
		$ann_id =~ s/^.+?\|.+?\|.+?\|(.+?)\|$/$1/ if $parse_ref;
		$ann_str = $ann_id;
		$ann_str = $protein_info_by_pid{$pid}->{"ann"} if defined $protein_info_by_pid{$pid};
	}
	
	print "$ogid\t$ann_str\t$ann_id\t";
	
	# compile an array of cell values (lengths, ids, or counts)
	# get the ids from the taxa_by_og hash, which contains protein id(s) keyed to taxon keyed to OG id
	foreach my $tax (@sorted_taxa) {
		my $replen  = 0;
		my $prntlen = 0;
		my $prntid  = "";
		
		# get the number of proteins in the OG from this taxon
		my $count = 0;
		$count = scalar keys %{$taxa_by_og{$ogid}->{$tax}} if defined $taxa_by_og{$ogid}->{$tax};
		
		if ($count > 0) {
			# if there is at least one protein, get the max length as a representative
			my @lengths_t = ();
			foreach my $pid (keys %{$taxa_by_og{$ogid}->{$tax}}) {
				$replen = $protein_info_by_pid{$pid}->{"length"} if $replen < $protein_info_by_pid{$pid}->{"length"};
				push @lengths_t, $protein_info_by_pid{$pid}->{"length"};
			}
			$prntid  = join("|", keys %{$taxa_by_og{$ogid}->{$tax}});
			#$prntlen = join("|", @lengths_t);
			$prntlen = $replen;
		}
		
		# record the representative length for this taxon
		push @lengths, $replen unless $replen == 0;
		
		if ($cell eq "l") {
			push @printables, $prntlen;
		} elsif ($cell eq "i") {
			push @printables, $prntid;
		} else {
			push @printables, $count;
		}
		
	}
	
	# print the length statistics
	print max(@lengths) . "\t" . mean(@lengths) . "\t" . stddev(@lengths) . "\t" . median(@lengths) . "\t" . mode(@lengths) . "\t";
	
	# convert lengths to pct of max
	if ($cell eq "lp") {
		my $denom = max(@lengths);
		for (my $i=0; $i < scalar(@printables); $i++) {
			$printables[$i] = sprintf( "%.1f", (100 * ($printables[$i] / $denom)) );
		}
	}

	# print the values
	print join("\t", @printables) . "\n";
}


exit;


sub trim {
	my $str=shift;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}



