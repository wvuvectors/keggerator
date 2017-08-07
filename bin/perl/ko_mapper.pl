#! /usr/bin/env perl -w
use strict;


my $progname = $0;
$progname =~ s/^.*?([^\/]+)$/$1/;

my $usage = "\n";
$usage .=   "Usage: $progname INDIR... [options]\n";
$usage .=   "Parses the KEGG module, pathway, and/or brite html files in INDIRs for id-to-KO mappings and prints them to STDOUT.\n";
$usage .=   "\n";


my @indir=();

while (@ARGV) {
  my $arg = shift;
  if ($arg eq '-h' or $arg eq '-help') {
  	die "$usage";
  } else {
  	push @indir, "$arg";
  }
}

die "no input directories provided!\n$usage" unless scalar @indir > 0;

my %map = ();

foreach my $dir (@indir) {

	opendir(my $indh, $dir) or die "FATAL : Can't open directory $dir: $!";
	my @src_files = grep !/^\./, readdir($indh);
	closedir $indh;

	foreach my $f (@src_files) {
		my $line;
		{
			open my $fh, "<", "$dir/$f" or die "FATAL : $!\n";
			local $/ = undef;
			$line = <$fh>;
			close $fh;
		}
	
		$line =~ s/\n//gi;
		#print Dumper($line);
		#die;
	
		while ($line =~ /<a href=\/dbget-bin\/www_bget\?(.+?)\starget.+?(?:&nbsp;){1,3}(.+?)</ig) {
			#print "$1";
			#die;
			my $ko = $1;
			my @ids = split /,/, $2, -1;
			foreach my $id (@ids) {
				next unless $id =~ /\|/;
				$id =~ s/^\s*//i;
				$map{$id} = $ko;
			}
		}
	}

}

foreach my $id (keys %map) {
	print "$id\t$map{$id}\n";
}

exit;

