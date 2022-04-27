#!/usr/bin/perl
## Pombert Lab 2022
my $version = '0.1';
my $name = 'descriptive_foldseek_matches.pl';
my $updated = '2022-04-26';

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
SYNOPSIS	Adds descriptive information from PDB headers to the foldseek matches;
		Parses results by quality scores, and concatenates the output into a single file

EXAMPLE		${name} \
		  -r /media/Data_2/PDB/PDB_titles.tsv \
		  -m *.fseek.gz \
		  -q 0.3 \
		  -b 5 \
		  -o foldseek.matches 

OPTIONS:
-r (--rcsb)	Tab-delimited list of RCSB structures and their titles ## see PDB_headers.pl 
-m (--matches)	Results from foldseek searches ## Supports GZIPPEd files; see run_foldseek.pl
-q (--quality)	Quality score cut-off [Default: 200]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: foldseek.matches]
-l (--log)	Error log file [Default: descriptive_matches.err]
-n (--nobar)	Turn off the progress bar
-x (--regex)	Regex to parse filenames: word (\\w+) or nonspace (\\S+) [Default: nonspace]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $rcsb;
my @matches;
my $qthreshold = 200;
my $best;
my $output = 'foldseek.matches';
my $log = 'descriptive_matches.err';
my $nobar;
my $regex = 'nonspace';
GetOptions(
	'r|rcsb=s' => \$rcsb,
	'm|matches=s@{1,}' => \@matches,
	'q|quality=s' => \$qthreshold,
	'b|best=i' => \$best,
	'o|output=s' => \$output,
	'l|log=s' => \$log,
	'n|nobar' => \$nobar,
	'x|regex=s' => \$regex
);

# open LOG, ">", "$log" or die "Can't create log file $log: $!\n";

my %rcsb_titles;
my %pfam_titles;
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

## Iterating through foldseek matches
open OUT, ">", "$output" or die "Can't create output file $output: $!\n";
my $total_matches = scalar(@matches);
while (my $match = shift@matches){

	my $rgx = '\S+';
	$regex = lc($regex);
	if ($regex eq 'word'){ $rgx = '\w+'; }

	my ($basename, $path) = fileparse($match);
	my ($prefix, $mode) = $basename =~ /^($rgx).*\.fseek(.gz)?$/;

	unless ($nobar) { ## Progress bar
		system "clear";
		my $remaining = "." x (int((scalar(@matches)/$total_matches)*100));
		my $progress = "|" x (100-int((scalar(@matches)/$total_matches)*100));
		my $status = "[".$progress.$remaining."]";
		print "Getting match descriptions from $path\n";
		print "\n\t$status\t".($total_matches-scalar(@matches))."/$total_matches\n";
	}

	## Working on foldseek file
	my $gzip = '';
	if ($match =~ /.gz$/){ $gzip = ':gzip'; }
	open MA, "<$gzip", "$match" or die "Can't read file $match: $!\n";
	print OUT '### '."$prefix"."\n";

	if ($nobar) { print "Getting descriptive matches from $match\n"; }

	my $hit_number = 0;
	while (my $line = <MA>){

		chomp $line;

		## Skipping comments
		if ($line =~ /^#/){ next; }
		else { $hit_number++; }

		## Working on matches
		my @data = split(/\s+/, $line);

		## Data columns for foldseek files are:
		# query,target,fident,alnlen,mismatch,gapopen,qstart,qend,tstart,tend,evalue,bits

		my $pdb_code;
		my $chain;
		if ($data[1] =~ /^pdb(\w{4}).ent.gz_(\S+)$/){
			$pdb_code = $1;
			$chain = $2;
		}
		elsif ($data[1] =~ /^pdb(\w{4}).ent.gz$/){
			$pdb_code = $1;
			$chain = 'A';
		}
		my $qscore = $data[-1];

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