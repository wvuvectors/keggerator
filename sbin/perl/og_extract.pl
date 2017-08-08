#! /usr/bin/env perl -w
use strict;

use POSIX qw(floor);


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname OGID [options]\n";
$usage .=   "Extracs OGID from the orthoMCL/OGRE .end file on STDIN and prints them to STDOUT.\n";
$usage .=   "       [-i F]   Read OGs to extract from file F, one per line, instead of using OG.\n";
$usage .=   "       [-c N]   OG ids are in column N of the input file [default: 0]. Requires -i.\n";
$usage .=   "       [-s S D] Extract sequences from fasta file S and write to dir D [default: OGseqs], one fasta file for each OG.\n";
$usage .=   "       [-x X]   Exclude sequences from the taxa in file X, one per line. Requires -s.\n";
$usage .=   "       [-p M]   Prune the output OGs to include at most M genes from each taxon [default: all].\n";
$usage .=   "\n";


my %uniq_ogs = ();
my @oglist   = ();
my ($fafile, $outdir, $prune, $idfile);
my $idcol = 0;
my %notaxa=();


while (@ARGV) {
	my $arg=shift;
	if ($arg eq '-h' or $arg eq '-help') {
		die "$usage";
	} elsif ($arg eq '-c' or $arg eq '-col') {
		defined ($idcol=shift) or die "FATAL : Malformed -c argument.\n$usage";
	} elsif ($arg eq '-i' or $arg eq '-infile') {
		defined ($idfile=shift) or die "FATAL : Malformed -i argument.\n$usage";
	} elsif ($arg eq '-p' or $arg eq '-prune') {
		defined ($prune=shift) or die "$usage";
		$prune =~ s/\D//gi;
		$prune=1 unless $prune>1;
	} elsif ($arg eq '-s' or $arg eq '-seq' or $arg eq '-sequences') {
		defined ($fafile=shift) or die "FATAL : Malformed -s argument.\n$usage";
		die "FATAL : $fafile is not readable.\n$usage" unless -f $fafile;

		if (defined $ARGV[0] and substr($ARGV[0],0,1) ne '-') {
			defined ($outdir=shift) or die "FATAL : Malformed -s argument.\n$usage";
			$outdir .= '/' unless (substr($outdir, -1, 1) eq '/');
			mkdir $outdir unless -d $outdir;
		}
	} elsif ($arg eq '-x' or $arg eq '-exclude') {
		defined (my $exfile=shift) or die "FATAL : Malformed -x argument.\n$usage";
		open my $ifh, "<", "$exfile" or die "FATAL : $!";
		while (<$ifh>) {
			chomp;
			$notaxa{lc $_}=0 unless /^\s*$/;
		}
		close $ifh;
	} else {
		$uniq_ogs{$arg} = 1;
		push @oglist, $arg;
	}
}

if (defined $idfile and -f "$idfile") {
	open my $ifh, "<", "$idfile" or die "FATAL : $!";
	while (my $line = <$ifh>) {
		chomp $line;
		my @a = split /\t/, $line, -1;
		next if scalar @a <= $idcol;
		my $ogid = $a[$idcol];
		$ogid =~ s/\s//gi;
		
		unless ($ogid =~ /^\s*$/ or $ogid =~ /^#/) {
			$uniq_ogs{$ogid} = 1;
			push @oglist, $ogid;
		}
	}
	close $ifh;
}


die "FATAL : No OGs provided!\n$usage" unless scalar @oglist > 0;
if (defined $fafile) {
	$outdir='OGseqs/'  unless defined $outdir;
	mkdir "$outdir" unless -d "$outdir";
}

my %ids_by_og=();

# loop through the input file from OrthoMCL/OGRE
# lists OGs, one per line, with all genes and their taxa
my %printables = ();
while (my $line=<>) {
	chomp $line;

	my ($ogid, $members) = split /\t/, $line, -1;
	$ogid =~ s/^ORTHOMCL(\S+?) .*$/$1/gi;

	if (defined $uniq_ogs{$ogid} or defined $uniq_ogs{"ORTHOMCL$ogid"}) {
		$printables{$ogid} = "$line";
		$ids_by_og{$ogid}={} unless defined $ids_by_og{$ogid};
		# get the protein ids in this OG
		my %taxa=();
		while ($members =~ /\s(.+?)\((.+?)\)/gi) {
			my $gid   = $1;
			my $taxon = lc $2;
			$taxa{$taxon}=0 unless defined $taxa{$taxon};
			$taxa{$taxon} = $taxa{$taxon} + 1;
			if (!defined $prune or $taxa{$taxon} <= $prune) {
				$gid .= '|' unless substr($gid, -1, 1) eq '|';
				$ids_by_og{$ogid}->{$gid} = 1 unless defined $notaxa{$taxon};
			}
		}
	}
}

# build the print order
my @sorted_ogids = ();
foreach my $ogid (@oglist) {
	push(@sorted_ogids, $ogid) if defined $printables{$ogid} or $ogid < 0;
}

foreach my $ogid (@sorted_ogids) {
	if (defined $printables{$ogid}) {
		print "$printables{$ogid}\n";
	} else {
		print "ORTHOMCL$ogid (0 genes,0 taxa):\t \n";
	}
}


if (defined $fafile) {
	my $seqs_by_id=getSequences($fafile);

	# print seqs to OG fasta files
	foreach my $ogid (keys %ids_by_og) {
		open my $ofh, ">", "${outdir}$ogid.fasta" or die "FATAL : $!";
		foreach my $id (keys %{$ids_by_og{$ogid}}) {
			print $ofh "$seqs_by_id->{$id}";
		}
		close $ofh;
	}
}


exit;



sub getSequences {
	my $f=shift;
	
	my $s={};
	
	my $id;
	my $seq='';
	open my $fh, "<", "$f" or die "FATAL : $!";
	while (<$fh>) {
		chomp;
		next if /^\s*$/;
		
		if (/^>/) {
			my $hdr=$_;
			if (defined $id) {
				$s->{$id}=$seq;
			}
			$seq="$hdr\n";
			$hdr =~ s/^>//;
			($id, my $ann) = split /\s+/, $hdr, 2;
			$id .= '|' unless substr($id, -1, 1) eq '|';
		} else {
			$seq .= "$_\n";
		}
	}
	
	if (defined $id) {
		$s->{$id}=$seq;
	}
	close $fh;
	
	return $s;
}


