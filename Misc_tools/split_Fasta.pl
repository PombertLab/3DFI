#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.4a';
my $name = 'split_Fasta.pl';
my $updated = '2021-09-02';

use strict; use warnings; use PerlIO::gzip; use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Splits a multifasta file into separate files, one per sequence. Can
		also subdivide fasta sequences into various segments using sliding windows. 
		
USAGE EXAMPLE	${name} \\
		  -f file.fasta \\
		  -o output_folder \\
		  -e fasta \\
		  -w \\
		  -s 150 \\
		  -l 75

OPTIONS:
-f (--fasta)	FASTA input file (supports gzipped files)
-o (--output)	Output directory [Default: Split_Fasta]
-e (--ext)	Desired file extension [Default: fasta]
-w (--window)	Split individual fasta sequences into fragments using sliding windows [Default: off]
-s (--size)	Size of the the sliding window [Default: 250 (aa)]
-l (--overlap)	Sliding window overlap [Default: 100 (aa)]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $fasta;
my $out = './Split_Fasta';
my $ext = 'fasta';
my $window;
my $window_size = 250;
my $window_overlap = 100;
GetOptions(
	'f|fasta=s' => \$fasta,
	'o|output=s' => \$out,
	'e|ext=s'	=> \$ext,
	'w|window' => \$window,
	's|size=i' => \$window_size,
	'l|overlap=i' => \$window_overlap,
);

## Creating output folder
unless (-d $out){
	mkdir ($out,0755) or die "Can't create directory $out: $!\n";
}

## Open multifasta file
my $gzip = '';
if ($fasta =~ /.gz$/){ $gzip = ':gzip'; }
open FASTA, "<$gzip", "$fasta" or die "Can't open FASTA file $fasta: $!\n";

## Storing fasta sequences under their locus
my %sequences; my $seq;
while (my $line = <FASTA>){
	chomp $line;
	if ($line =~ />(\S+)/){
		$seq = $1;

		## Replacing problematic filename characters from fasta headers with underscores.
		$seq =~ s/[\|\(\)\\\#\@\:\;\?\!\$\%\^\&\*\'\"\~\+\=\[\]]/_/g;
	}
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
			open OUT, ">", "$out/${locus}_$start-$end.$ext" or die "Can't open ${locus}_$start-$end.$ext in directory $out/: $!\n";
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