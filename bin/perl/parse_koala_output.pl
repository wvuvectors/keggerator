#! /usr/bin/env perl -w
use strict;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname MAP [options]\n";
$usage .=   "Parses the KEGG module, pathway, and/or brite html files, tabulates by gene, and writes to STDOUT. At ";
$usage .=   "least one of -m, -p, or -b must be set. Uses the id->ko mapping file(s) in MAP (file or dir of files).\n";
$usage .=   "       [-debug] Print debug files to working directory.\n";
$usage .=   "       [-nohdr] Do not print the output header line.\n";
$usage .=   "       [-m MD]  Path to directory of KEGG module files (html).\n";
$usage .=   "       [-p PD]  Path to directory of KEGG pathway files (html).\n";
$usage .=   "       [-b BD]  Path to directory of KEGG brite files (html).\n";
$usage .=   "       [-a A]   Use annotations in the fasta file A.\n";
$usage .=   "       [-o O]   Output summaries by organism in A, using output file base O.\n";
$usage .=   "\n";

#my %EXCLUDE = ("map01100" => 1, "ko00001" => 1, "ko00002" => 1);
my %EXCLUDE = ();

my ($mdir, $pdir, $bdir, $annfile, $outbase, $map);
my ($debug, $nohdr) = (0,0);


while (@ARGV) {
  my $arg = shift;
  if ($arg eq '-h' or $arg eq '-help') {
  	die "$usage";
  } elsif ($arg eq '-debug') {
  	$debug=1;
  } elsif ($arg eq '-nohdr') {
  	$nohdr=1;
  } elsif ($arg eq '-m' or $arg eq '-mod') {
  	defined ($mdir=shift) or die "FATAL : -m argument is malformed.\n$usage";
  	die "FATAL: -m argument \"$mdir\" is not a readable file or dir.\n$usage" unless -f "$mdir" or -d "$mdir";
  } elsif ($arg eq '-p' or $arg eq '-path') {
  	defined ($pdir=shift) or die "FATAL : -p argument is malformed.\n$usage";
  	die "FATAL: -p argument \"$pdir\" is not a readable file or dir.\n$usage" unless -f "$pdir" or -d "$pdir";
  } elsif ($arg eq '-b' or $arg eq '-brite') {
  	defined ($bdir=shift) or die "FATAL : -b argument is malformed.\n$usage";
  	die "FATAL: -b argument \"$bdir\" is not a readable file or dir.\n$usage" unless -f "$bdir" or -d "$bdir";
  } elsif ($arg eq '-a' or $arg eq '-ann') {
  	defined ($annfile=shift) or die "FATAL : -a argument is malformed.\n$usage";
  	die "FATAL: -a argument \"$annfile\" is not a readable file.\n$usage" unless -f "$annfile";
  } elsif ($arg eq '-o' or $arg eq '-out') {
  	defined ($outbase=shift) or die "FATAL : -o argument is malformed.\n$usage";
  } else {
  	$map = "$arg";
  }
}

die "FATAL : No map provided!\n$usage\n" unless defined $map;
die "FATAL : $map is not readable!\n$usage\n" unless -d "$map" or -f "$map";


my $sumfile = "koala.sum.txt";
$sumfile = "$outbase.sum.txt" if defined $outbase;

my $catfile = "koala.catalog.txt";
$catfile = "$outbase.catalog.txt" if defined $outbase;

my %id2cats  =();
my %modules  =();
my %pathways =();
my %brites   =();


# read in the id->ko map files
# store map in the id2ko hash

my @mapfiles = ();

if ( -d "$map" ) {
	opendir(my $mapdh, $map) or die "FATAL : Can't open directory $map: $!";
	@mapfiles = grep !/^\./, readdir($mapdh);
	for (my $i=0; $i<scalar(@mapfiles); $i++) {
		$mapfiles[$i] = "$map/$mapfiles[$i]";
	}
	closedir $mapdh;
} else {
	push @mapfiles, "$map";
}

foreach my $mapfile (@mapfiles) {
	open my $mapFH, "<", "$mapfile" or die "$!";
	while (<$mapFH>) {
		chomp;
		next if /^\s*$/;
	
		my ($id, $ko) = split /\t/, "$_", -1;
		$ko='' unless defined $ko;
		unless (defined $id2cats{$id}) {
			$id2cats{$id} = {
												'ko'       => '',
												'product'  => '',
												'organism' => '',
												'modules'  => {},
												'pathways' => {},
												'brites'   => {}
											};
		}
		$id2cats{$id}->{'ko'} = $ko;
	}
	close $mapFH;
}

# read in the product annotations, if a fasta file is provided
if (defined $annfile) {
	open my $afh, "<", "$annfile" or die "$!";
	while (<$afh>) {
		chomp;
		if (/^>/) {
			my ($id, $ann) = split /\s/, "$_", 2;
			$id =~ s/^>//i;
			unless (defined $id2cats{$id}) {
				$id2cats{$id} = {
													'ko'       => '',
													'product'  => '',
													'organism' => '',
													'modules'  => {},
													'pathways' => {},
													'brites'   => {}
												};
			}
			
			my $org = "";
			if ($ann =~ /^(.*)\[(.+?)\]\s*$/) {
				$ann = $1;
				$org = $2;
			}
			$org =~ s/\s/_/g;
			$org =~ s/\//-/g;
			$org =~ s/'//g;
			$org =~ s/"//g;
			$ann =~ s/\s+$//;
			$id2cats{$id}->{'product'} = "$ann";
			$id2cats{$id}->{'organism'} = "$org";
		}
	}
	close $afh;
}

my ($supercat, $cat, $subcat, $ko);
my $doread=0;


# process the module files, if provided
opendir(my $mdh, $mdir) or die "FATAL : Can't open directory $mdir: $!";
my @mfiles = grep !/^\.\.?$/, readdir($mdh);
closedir $mdh;

foreach my $mfile (@mfiles) {
	if (defined $mfile and -f "$mdir/$mfile") {
		my $mid;
		open my $mFH, "<", "$mdir/$mfile" or die "$!";
		while (<$mFH>) {
			chomp;
	
			$doread=1 if /Module Reconstruction Result/;
			next unless $doread==1;

			if (/^&nbsp;&nbsp;<b>(.+?)<\/b><br\s?\/?><br\s?\/?>$/i) {
				# supercategory
				$supercat = $1;
				#print "supercat: $supercat\n";
			} elsif  (/^&nbsp;&nbsp;&nbsp;&nbsp;<b>(.+?)<\/b><br\s?\/?>$/i) {
				# category
				$cat = $1;
				#print "cat: $cat\n";
			} elsif (/^&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;([^&].+?)<br\s?\/?>$/i) {
				# subcategory
				$subcat = $1;
				#print "subcat: $subcat\n";
			} elsif (/<a href=.+?show_module.+?>(.+?)<\/a>&nbsp;(.+?)\[PATH.+?\].+?&nbsp;&nbsp;\((.+?)\)<br\s?\/?>$/i) {
				# module
				$mid = $1;
				my $name  = $2;
				my $state = $3;

				$name =~ s/ +$//i;

				if ($state =~ /block/i) {
					$state =~ s/ block(s?) missing//;
				} else {
					$state = 0;
				}
		
				$modules{$mid} = {'id' => $mid, 'name' => $name, 'missing' => $state, 'super' => $supercat, 'cat' => $cat, 'sub' => $subcat, 'members' => {}};
			} elsif (/<a href=.+?www_bget.+?>(.+?)<\/a>&nbsp;(.*?)<br\s?\/?>$/i) {
				# ko
				($ko, my $idstr) = ($1, $2);
			
				if (defined $idstr and '' ne "$idstr") {
					$idstr =~ s/<br\s?\/?>$//;

					foreach my $id (split /,\s*/i, $idstr) {

						next unless defined $id2cats{$id};
						#$id2cats{$id}->{'ko'} = $ko unless defined $id2cats{$id}->{'ko'};
				
						$id2cats{$id}->{'modules'}->{$mid} = $modules{$mid}->{'name'};
				
						$modules{$mid}->{'members'}->{$id} = 1;

						#unless ("$ko" eq "$id2cats{$id}->{ko}") {
						#	print STDERR "WARN  : $id has mismatched KO ids (map $id2cats{$id}->{ko}, module $ko).\n";
						#	$id2cats{$id}->{'ko_from_module'} = $ko;
						#}

					}
				}
			}
		}
		close $mFH;
	}
}

($supercat, $cat, $subcat, $ko) = (undef, undef, undef, undef);
$doread=0;


# process the pathway files, if provided
opendir(my $pdh, $pdir) or die "FATAL : Can't open directory $pdir: $!";
my @pfiles = grep !/^\.\.?$/, readdir($pdh);
closedir $pdh;

foreach my $pfile (@pfiles) {
	if (defined $pfile and -f "$pdir/$pfile") {
		my $pid;
		open my $pFH, "<", "$pdir/$pfile" or die "$!";
		while (<$pFH>) {
			chomp;
		
			$doread=1 if /Pathway Reconstruction Result/;
			next unless $doread==1;
		
			if (/^<b>(.+?)<\/b>$/i) {
				# supercategory
				$supercat = $1;
				#print "supercat: $supercat\n";
			} elsif  (/^\s{1}(\S.+?)$/i) {
				# category
				$cat = $1;
				#print "cat: $cat\n";
			} elsif (/<a href=.+?show_pathway.+?>(.+?)<\/a>&nbsp;\(<a href=\"javascript\:display\(.*?(map\d+).*?\)\">.+<\/a>\)/i) {
				# pathway
				$pid = $2;

				$pathways{$pid} = {'id' => $pid, 'name' => $1, 'super' => $supercat, 'cat' => $cat, 'members' => {}};
			} elsif (/<a href=.+?www_bget.+?>(.+?)<\/a><br\s?\/?>$/i) {
				# ko
				$ko = $1;
			} elsif (/^&nbsp;&nbsp;&nbsp;(.+?)$/i) {
				my $idstr = $1;

				if (defined $idstr and '' ne "$idstr") {
					$idstr =~ s/<br\s?\/?>$//;
		
					foreach my $id (split /,\s*/i, $idstr) {
		
						next unless defined $id2cats{$id};
						#$id2cats{$id}->{'ko'} = $ko unless defined $id2cats{$id}->{'ko'};

						$id2cats{$id}->{'pathways'}->{$pid} = $pathways{$pid}->{'name'};
				
						$pathways{$pid}->{'members'}->{$id} = 1;
		
						#unless ("$ko" eq "$id2cats{$id}->{ko}") {
						#	print STDERR "WARN  : $id has mismatched KO ids (map $id2cats{$id}->{ko}, pathway $ko).\n";
						#	$id2cats{$id}->{'ko_from_pathway'} = $ko;
						#}
					}
				}
			}
		}
		close $pFH;
	}
}


($supercat, $cat, $subcat, $ko) = (undef, undef, undef, undef);
$doread=0;


# process the brite file, if provided
opendir(my $bdh, $bdir) or die "FATAL : Can't open directory $bdir: $!";
my @bfiles = grep !/^\.\.?$/, readdir($bdh);
closedir $bdh;

foreach my $bfile (@bfiles) {
	if (defined $bfile and -f "$bdir/$bfile") {
		my $bid;
		open my $bFH, "<", "$bdir/$bfile" or die "$!";
		while (<$bFH>) {
			chomp;
		
			$doread=1 if /Brite Reconstruction Result/;
			next unless $doread==1;
		
			if (/^<b>(.+?)<\/b>$/i) {
				# supercategory
				$supercat = $1;
				#print "supercat: $supercat\n";
			} elsif  (/^\s{1}(\S.+?)$/i) {
				# category
				$cat = $1;
				#print "cat: $cat\n";
			} elsif (/<a href=.+?search_brite_mapping\?htext=(.+?)&.+?>(.+?)<\/a>/i) {
				# pathway
				$bid   = $1;

				$brites{$bid} = {'id' => $bid, 'name' => $2, 'super' => $supercat, 'cat' => $cat, 'members' => {}};
			} elsif (/<a href=.+?www_bget.+?>(.+?)<\/a><br\/>$/i) {
				# ko
				$ko = $1;
			} elsif (/^&nbsp;&nbsp;&nbsp;(.+?)$/i) {
				my $idstr = $1;

				if (defined $idstr and '' ne "$idstr") {
					$idstr =~ s/<br\s?\/?>//gi;
		
					foreach my $id (split /,\s*/i, $idstr) {
		
						next unless defined $id2cats{$id};
						#$id2cats{$id}->{'ko'} = $ko unless defined $id2cats{$id}->{'ko'};

						$id2cats{$id}->{'brites'}->{$bid} = $brites{$bid}->{'name'};
				
						$brites{$bid}->{'members'}->{$id} = 1;
		
						#unless ("$ko" eq "$id2cats{$id}->{ko}") {
						#	print STDERR "WARN  : $id has mismatched KO ids (map $id2cats{$id}->{ko}, brite $ko).\n";
						#	$id2cats{$id}->{'ko_from_brite'} = $ko;
						#}
					}
				}
			}
		}
		close $bFH;
	}
}


my @ids_by_org = sort { $id2cats{$a}->{"organism"} cmp $id2cats{$b}->{"organism"} || $a cmp $b } keys %id2cats;
my $org = "";
my $orgFH;

foreach my $id (@ids_by_org) {
	my $gene = $id2cats{$id};
	my ($mstr, $pstr, $bstr) = ("", "", "");
	foreach (sort keys %{$gene->{'modules'}}) {
		next if defined $EXCLUDE{$_};
		$mstr .= "$gene->{modules}->{$_}||$_||$modules{$_}->{super}|$modules{$_}->{cat}|$modules{$_}->{sub}|||";
	}
	foreach (sort keys %{$gene->{'pathways'}}) {
		next if defined $EXCLUDE{$_};
		$pstr .= "$gene->{pathways}->{$_}||$_||$pathways{$_}->{super}|$pathways{$_}->{cat}|||";
	}
	foreach (sort keys %{$gene->{'brites'}}) {
		next if defined $EXCLUDE{$_};
		$bstr .= "$gene->{brites}->{$_}||$_||$brites{$_}->{super}|$brites{$_}->{cat}|||";
	}
	
	print "$id\t$gene->{organism}\t$gene->{product}";
	if (defined $gene->{'ko'} and "" ne "$gene->{ko}") {
		print "\t$gene->{ko}\t$mstr\t$pstr\t$bstr";
	} else {
		print "\t\t\t\t\t\t\t";
	}
	print "\n";
	
	next unless defined $outbase;
	
	if ("$org" ne "$gene->{organism}") {
		$org = $gene->{'organism'};
		print STDERR "Now processing $org\n" if $debug == 1;
		my $orgstr = $org;
		$orgstr =~ s/\s/_/g;
		$orgstr =~ s/\//-/g;
		$orgstr =~ s/'//g;
		$orgstr =~ s/"//g;
		close $orgFH if defined $orgFH;
		open $orgFH, ">>", "$outbase.$orgstr.txt" or die "$!";
	}
	
	print $orgFH "$id\t$gene->{organism}\t$gene->{product}";
	if (defined $gene->{'ko'} and "" ne "$gene->{ko}") {
		print $orgFH "\t$gene->{ko}\t$mstr\t$pstr\t$bstr";
	} else {
		print $orgFH "\t\t\t\t";
	}
	print $orgFH "\n";
	
	
}
close $orgFH if defined $orgFH;


if ($debug == 1) {
	open my $debug1FH, ">>", "debug.modules.txt" or die "$!";
	print $debug1FH Dumper(\%modules);
	close $debug1FH;

	open my $debug2FH, ">>", "debug.brites.txt" or die "$!";
	print $debug2FH Dumper(\%brites);
	close $debug2FH;

	open my $debug3FH, ">>", "debug.pathways.txt" or die "$!";
	print $debug3FH Dumper(\%pathways);
	close $debug3FH;
}

exit;

