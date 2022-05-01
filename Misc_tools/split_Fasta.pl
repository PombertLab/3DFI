#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.5';
my $name = 'split_Fasta.pl';
my $updated = '2021-09-07';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use PerlIO::gzip;

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Splits multifasta files into separate files, one per sequence. Can
		also subdivide fasta sequences into various segments using sliding windows. 
		
USAGE EXAMPLE	${name} \\
		  -f *.fasta \\
		  -o output_folder \\
		  -e fasta \\
		  -w \\
		  -s 150 \\
		  -l 75

OPTIONS:
## General
-f (--fasta)	FASTA input file(s) (supports .gz gzipped files)
-o (--output)	Output directory [Default: Split_Fasta]
-e (--ext)	Desired file extension [Default: fasta]
-v (--verbose)	Adds verbosity

## Fasta header parsing
-r (--regex)	word (\\w+) or nonspace (\\S+) [Default: word]

## Sliding window options
-w (--window)	Split individual fasta sequences into fragments using sliding windows [Default: off]
-s (--size)	Size of the the sliding window [Default: 250 (aa)]
-l (--overlap)	Sliding window overlap [Default: 100 (aa)]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @fasta;
my $out = './Split_Fasta';
my $ext = 'fasta';
my $verbose;
my $regex = 'word';
my $window;
my $window_size = 250;
my $window_overlap = 100;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|output=s' => \$out,
	'e|ext=s'	=> \$ext,
	'v|verbose' => \$verbose,
	'r|regex=s' => \$regex,
	'w|window' => \$window,
	's|size=i' => \$window_size,
	'l|overlap=i' => \$window_overlap,
);

## Checking regex
my $rgx;
$regex = lc($regex);
if ($regex eq 'word'){ $rgx = '\w+'; }
elsif (($regex eq 'nonspace') or ($regex eq 'ns')){ $rgx = '\S+'; }
else {
	print "[E] Unrecognized regular expression. Please use: word or nonspace (ns) ...\n";
	exit;
}

## Creating output folder
unless (-d $out){
	mkdir ($out,0755) or die "Can't create directory $out: $!\n";
}

## Working on FASTA file(s)

my %sequence_names; ## Hash to check for duplicated sequence names, if any

while (my $fasta = shift@fasta){

	my $gzip = '';
	if ($fasta =~ /.gz$/){ $gzip = ':gzip'; }

	## Pass 1: Check if file is a single or multifasta 
	open FASTA, "<$gzip", "$fasta" or die "Can't open FASTA file $fasta: $!\n";
	my $fasta_type;
	my $counter = 0;
	while (my $line = <FASTA>){
		chomp $line;
		if ($line =~ /^>/){ $counter++; }
	}
	if ($gzip eq ':gzip'){ 
		binmode FASTA, ":gzip(none)"; 
	}

	if ($counter == 1){ $fasta_type = 'single fasta file'; }
	elsif ($counter > 1) { $fasta_type = 'multifasta file'; }
	elsif ($counter == 0) { $fasta_type = undef; }
	close FASTA;

	if ($fasta_type){
		if ($verbose){ print "Working on FASTA file(s): $fasta - $counter sequence(s); $fasta_type\n"; }
	}
	else { print "[E] No FASTA header found in $fasta. Check input file\n"; }

	## Pass 2: Working on file
	open FASTA, "<$gzip", "$fasta" or die "Can't open FASTA file $fasta: $!\n";
	my %sequences;
	my $seq;

	while (my $line = <FASTA>){
		chomp $line;

		## FASTA headers
		if ($line =~ /^>/){

			## Typical NCBI .faa FASTA headers:
			## >NP_584537.1 similarity to HSP70-RELATED PROTEIN [Encephalitozoon cuniculi GB-M1]
			## >NP_584578.1 MPS1-LIKE THR/TYR DUAL SPECIFICITY PROTEIN KINASE [Encephalitozoon cuniculi GB-M1]
			## >$accession\.$version

			## Typical MicrosporidiaDB _AnnotatedProteins.fasta FASTA headers:
			## >ECU01_0010-t26_1-p1 | transcript=ECU01_0010-t26_1 ...
			## >ECU01_0080-t26_1-p1 | transcript=ECU01_0080-t26_1 ...
			## >$locus_tag\$db_entry

			## >(\w+) => accession number is unique to both

			## Grab by regular expression (default: \w+)
			if ($line =~ />($rgx)/){
				$seq = $1;

				## If $rgx = \S+, will grab problematic characters for filenames
				## Replacing those characters with underscores
				$seq =~ s/[\|\(\)\\\#\@\:\;\?\!\$\%\^\&\*\'\"\~\+\=\[\]]/_/g;

				## Check if name is unique
				if (exists $sequence_names{$seq}){

					push (@{$sequence_names{$seq}{'file'}}, $fasta);
					my @duplicates = @{$sequence_names{$seq}{'file'}};

					## Debugging
					print "[E]: $seq name is duplicated! => ";
					for (0..$#duplicates-1){
						print "found in $duplicates[$_]; ";
					}
					print "$duplicates[$#duplicates] => keeping the last one\n";
					$sequences{$seq} = undef;
				}
				else {
					push (@{$sequence_names{$seq}{'file'}}, $fasta); ## source 
				}
			}
		}

		## Sequence lines
		else { $sequences{$seq} .= $line; }
	}
	if ($gzip eq ':gzip'){ 
		binmode FASTA, ":gzip(none)"; 
	}

	## Printing sequences
	for my $locus (keys(%sequences)){

		my $sequence = $sequences{$locus};

		## Regular FASTA file, no sliding windows
		unless ($window){
			open OUT, ">", "$out/$locus.$ext" or die "Can't open $locus.$ext in directory $out: $!\n";
	
			if ($verbose){ print "  Creating $locus.$ext in $out ...\n"; }
	
			print OUT ">$locus\n";
			my @fsa = unpack ("(A60)*", $sequence);
			while (my $fsa = shift @fsa){ 
				print OUT "$fsa\n";
			}
			close OUT;
		}
		
		## Creating FASTA files with sliding windows instead, if specified
		my $buffer = scalar(split("",length($sequence)));
		if ($window){
			my $start = sprintf("%0${buffer}d",0);
			my $remaining_aa = length($sequence);
			ITER: while (0 == 0){
				$remaining_aa -= ($window_size - $window_overlap);
				my $end;
				## Unless there are enough amino acids remaining after this subsequence for another windowed slice,
				## extend the end point to the last amino acid in the sequence
				unless ($remaining_aa > $window_size){
					$end =  sprintf("%0${buffer}d",length($sequence)-1);
				}
				else {
					$end = sprintf("%0${buffer}d", $start + $window_size);
				}
				
				my $subsequence = substr($sequence,$start,$end);
				my @subfsa = unpack ("(A60)*",$subsequence);
				
				my $filename = "${locus}_$start-$end.$ext";
				open OUT, ">", "$out/$filename" or die "Can't create $filename in $out/: $!\n";
				if ($verbose){ print "Creating $filename in $out...\n"; }

				while (my $subfsa = shift(@subfsa)){
					print OUT "$subfsa\n";
				}
				if ($end == length($sequence)-1){
					last ITER;
				}
				$start += ($window_size - $window_overlap);
				$start = sprintf("%0${buffer}d", $start);
			}
		}
	}

}