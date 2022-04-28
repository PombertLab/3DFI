#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.8';
my $name = 'descriptive_matches.pl';
my $updated = '2022-04-27';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use PerlIO::gzip; 

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Adds descriptive information from PDB headers to the foldseek/gesamt matches;
		Parses results by quality scores, and concatenates the output into a single file

EXAMPLE		${name} \\
		  -a gesamt \\
		  -r /media/Data_2/PDB/PDB_titles.tsv \\
		  -m *.gesamt.gz \\
		  -q 0.3 \\
		  -b 5 \\
		  -o GESAMT.matches

OPTIONS:
-a (--align)	Structural alignment tool used: foldseek or gesamt [Default: gesamt]
-r (--rcsb)	Tab-delimited list of RCSB structures and their titles ## see PDB_headers.pl 
-m (--matches)	Results from homology searches ## Supports GZIPPEd files; see run_GESAMT.pl/run_foldseek.pl
-q (--qscore)	Quality score cut-off [Default: 0.3]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: Gesamt.matches]
-n (--nobar)	Turn off the progress bar
-x (--regex)	Regex to parse filenames: word (\\w+) or nonspace (\\S+) [Default: nonspace]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $aligner = 'gesamt';
my $rcsb;
my @matches;
my $qthreshold = 0.3;
my $best;
my $output = 'GESAMT.matches';
my $nobar;
my $regex = 'nonspace';
GetOptions(
	'a|align=s' => \$aligner,
	'r|rcsb=s' => \$rcsb,
	'm|matches=s@{1,}' => \@matches,
	'q|qscore=s' => \$qthreshold,
	'b|best=i' => \$best,
	'o|output=s' => \$output,
	'n|nobar' => \$nobar,
	'x|regex=s' => \$regex
);

my %rcsb_titles;
if ($rcsb){
	## Creating a database of RSCB stuctures and their descriptions; PDB 4-letter code => description
	open DB, "<", "$rcsb" or die "Can't open tab-delimited file $rcsb: $!\n";
	while (my $line = <DB>){
		chomp $line;
		my @columns = split ("\t", $line);
		my $pdb_locus = $columns[0];
		my $chain_or_title = $columns[1];
		my $description = $columns[2];
		$rcsb_titles{$pdb_locus}{$chain_or_title} = $description;
	}
}

## Iterating through foldseek/Gesamt matches
open OUT, ">", "$output" or die "Can't create output file $output: $!\n";
my $total_matches = scalar(@matches);
while (my $match = shift@matches){

	my $rgx = '\S+';
	$regex = lc($regex);
	if ($regex eq 'word'){ $rgx = '\w+'; }

	my ($basename, $path) = fileparse($match);
	my $prefix;
	my $mode;
	if ($aligner eq 'gesamt'){
		($prefix, $mode) = $basename =~ /^($rgx).*\.(normal|high).gesamt(.gz)?$/;
	}
	elsif ($aligner eq 'foldseek'){
		($prefix) = $basename =~ /^($rgx).*\.fseek(.gz)?$/;
	}

	unless ($nobar) { ## Progress bar
		system "clear";
		my $remaining = "." x (int((scalar(@matches)/$total_matches)*100));
		my $progress = "|" x (100-int((scalar(@matches)/$total_matches)*100));
		my $status = "[".$progress.$remaining."]";
		print "Getting match descriptions from $path\n";
		print "\n\t$status\t".($total_matches-scalar(@matches))."/$total_matches\n";
	}

	## Working on foldseek / GESAMT file
	my $gzip = '';
	if ($match =~ /.gz$/){ $gzip = ':gzip'; }
	open MA, "<$gzip", "$match" or die "Can't read file $match: $!\n";

	## Header per protein
	if ($aligner eq 'gesamt'){
		print OUT '### '."$prefix"."; Query mode = $mode\n";
	}
	elsif ($aligner eq 'foldseek'){
		print OUT '### '."$prefix"."\n";
	}

	if ($nobar) { print "  Getting descriptive matches from $match\n"; }

	my $hit_number = 0;
	while (my $line = <MA>){

		chomp $line;

		## Skipping comments
		if ($line =~ /^#/){ next; }
		else { $hit_number++; }

		## Working on matches
		my @data = split(/\s+/, $line);

		my $pdb_code;
		my $chain;
		my $qscore;

		if ($aligner eq 'gesamt'){
			# Data columns for GESAMT files are:
			# Hit number, PDB code, Chain ID, Q-score, RMSD, Sequence identity,
			# number of aligned residues, number of residues, file
			$pdb_code = lc($data[2]);
			$chain = $data[3];
			$qscore = $data[4];
		}
		elsif ($aligner eq 'foldseek'){
			## Data columns for foldseek files are:
			# query, target, fident, alnlen, mismatch, gapopen, qstart, qend,
			# tstart, tend, evalue, bits
			if ($data[1] =~ /^pdb(\w{4}).ent.gz_(\S+)$/){
				$pdb_code = $1;
				$chain = $2;
			}
			elsif ($data[1] =~ /^pdb(\w{4}).ent.gz$/){
				$pdb_code = $1;
				$chain = 'A';
			}
			$qscore = $data[-1];
		}

		## Printing information
		if ($qscore >= $qthreshold){
			if ($best){
				if ($best >= $hit_number){
					if ($rcsb){
						print OUT "$prefix\t";
						for (1..$#data){ print OUT "$data[$_]\t"; }
						if ($rcsb_titles{$pdb_code}){
							print OUT "$rcsb_titles{$pdb_code}{$chain}\n";
						}
						else {
							print OUT "No PDB entry. Verify if obsolete PDB ID...\n";
						}
					}
				}
			}
			else {
				if ($rcsb){
					print OUT "$prefix\t";
					for (1..$#data){ print OUT "$data[$_]\t"; }
					if ($rcsb_titles{$pdb_code}){
						print OUT "$rcsb_titles{$pdb_code}{$chain}\n";
					}
					else {
						print OUT "No PDB entry. Verify if obsolete PDB ID...\n";
					}
				}
			}
		}
	}

	if ($gzip eq ':gzip'){ binmode MA, ":gzip(none)"; }

}