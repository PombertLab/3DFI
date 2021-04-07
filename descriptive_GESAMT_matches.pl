#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.6';
my $name = 'descriptive_GESAMT_matches.pl';
my $updated = '2021-04-07';

use strict; use warnings; use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Adds descriptive information from PDB headers to the gesamt matches;
		Parses results by Q-scores, and concatenates the output into a single file

EXAMPLE		${name} \\
		  -t /media/Data_2/PDB/PDB_titles.tsv \\
		  -m *.gesamt \\
		  -q 0.3 \\
		  -b 5 \\
		  -o GESAMT.matches 

OPTIONS:
-t (--tsv)	Tab-delimited list of RCSB structures and their titles ## see PDB_headers.pl 
-m (--matches)	Results from GESAMT searches ## see run_GESAMT.pl
-q (--qscore)	Q-score cut-off [Default: 0.3]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: Gesamt.matches]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $tsv;
my @matches;
my $qthreshold = 0.3;
my $best;
my $output = 'GESAMT.matches';
GetOptions(
	't|tsv=s' => \$tsv,
	'm|matches=s@{1,}' => \@matches,
	'q|qscore=s' => \$qthreshold,
	'b|best=i' => \$best,
	'o|output=s' => \$output
);

### Creating a database of RSCB stuctures and their descriptions; PDB 4-letter code => description
my %RCSB;

# Doing a first pass for memory management, grabbing only pdb codes from the GESAMT searches
my @files = @matches;
while (my $file = shift@files){
	open FH, "<", "$file" or die "Can't read file $file: $!\n";
	while (my $line = <FH>){
		chomp $line;
		if ($line =~ /^\s+(\d+)\s+(\w+)\s+(\w+)\s+(\S+)/){
			my $hit_number = $1;
			my $pdb_code = $2;
			$RCSB{$pdb_code} = 1;
		}
	}
	close FH;
}

# Populating RCSB database if key is present in our matches
open DB, "<", "$tsv" or die "Can't open tab-delimited file $tsv: $!\n";
while (my $line = <DB>){
	chomp $line;
	if ($line =~ /^(\S+)\t(.*)$/){
		my $key = uc($1);
		my $description = $2;
		if (exists $RCSB{$key}){ $RCSB{$key} = $description; }
	}
}

## Iterating through Gesamt matches
open OUT, ">", "$output" or die "Can't create output file $output: $!\n";
while (my $match = shift@matches){

	open MA, "<", "$match" or die "Can't read file $match: $!\n";
	my ($prefix, $suffix) = $match =~ /^(\S+)\.(\w+.gesamt)$/;
	print OUT '### '."$prefix\n";

	while (my $line = <MA>){
		chomp $line;
		if ($line =~ /^\s+(\d+)\s+(\w+)\s+(\w+)\s+(\S+)/){
			my $hit_number = $1;
			my $pdb_code = $2;
			my $chain = $3;
			my $qscore = $4;
			if ($qscore >= $qthreshold){
				if ($best){
					if ($best >= $hit_number){
						print OUT "$prefix\t$line\t$RCSB{$pdb_code}\n";
					}
				}
				else { print OUT "$prefix\t$line\t$RCSB{$pdb_code}\n"; }
			}
		}
	}
}
