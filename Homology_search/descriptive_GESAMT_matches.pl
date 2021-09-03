#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.7b';
my $name = 'descriptive_GESAMT_matches.pl';
my $updated = '2021-09-03';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Adds descriptive information from PDB headers to the gesamt matches;
		Parses results by Q-scores, and concatenates the output into a single file

EXAMPLE		${name} \
		  -r /media/Data_2/PDB/PDB_titles.tsv \
		  -m *.gesamt \
		  -q 0.3 \
		  -b 5 \
		  -o GESAMT.matches 

OPTIONS:
-r (--rcsb)	Tab-delimited list of RCSB structures and their titles ## see PDB_headers.pl 
-p (--pfam)	Tab-delimited list of PFAM structures and their titles (http://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz)
-m (--matches)	Results from GESAMT searches ## see run_GESAMT.pl
-q (--qscore)	Q-score cut-off [Default: 0.3]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: Gesamt.matches]
-l (--log)	Log file [Default: descriptive_matches.log]
-n (--nobar)	Turn off the progress bar
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $rcsb;
my $pfam;
my @matches;
my $qthreshold = 0.3;
my $best;
my $output = 'GESAMT.matches';
my $log = 'descriptive_matches.log';
my $nobar;
GetOptions(
	'r|rcsb=s' => \$rcsb,
	'p|pfam=s' => \$pfam,
	'm|matches=s@{1,}' => \@matches,
	'q|qscore=s' => \$qthreshold,
	'b|best=i' => \$best,
	'o|output=s' => \$output,
	'l|log=s' => \$log,
	'n|nobar' => \$nobar
);

open LOG, ">", "$log" or die "Can't create log file $log: $!\n";

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
elsif ($pfam){
	## Creating a database of PFAM structures and their descriptions; PFAM 5-number code => description
	open DB, "<", "$pfam" or die "Can't open tab-delimited file $pfam: $!\n";
	while (my $line = <DB>){
		chomp $line;
		my @data = split("\t",$line);
		$pfam_titles{$data[0]} = $data[4];
	}
}

## Iterating through Gesamt matches
open OUT, ">", "$output" or die "Can't create output file $output: $!\n";
my $total_matches = scalar(@matches);
while (my $match = shift@matches){

	my ($basename, $path) = fileparse($match);
	my ($prefix, $mode) = $basename =~ /^(\S+)\.(normal|high).gesamt$/;

	unless ($nobar) { ## Progress bar
		system "clear";
		my $remaining = "." x (int((scalar(@matches)/$total_matches)*100));
		my $progress = "|" x (100-int((scalar(@matches)/$total_matches)*100));
		my $status = "[".$progress.$remaining."]";
		print "Getting match descriptions from $path\n";
		print "\n\t$status\t".($total_matches-scalar(@matches))."/$total_matches\n";
	}

	## Working on GESAMT file
	open MA, "<", "$match" or die "Can't read file $match: $!\n";
	print OUT '### '."$prefix"."; Query mode = $mode\n";

	if ($nobar) { print "Getting descriptive matches from $match\n"; }

	while (my $line = <MA>){
		chomp $line;

		## Skipping comments
		if ($line =~ /^#/){ next; }

		## Working on matches
		my @data = split(/\s+/, $line);

		## Data columns for GESAMT files are:
		# Hit number
		# PDB code
		# Chain ID
		# Q-score
		# RMSD
		# Sequence identity
		# Number of aligned residues
		# Number of residues
		# File

		my $hit_number = $data[1];
		my $pdb_code;
		my $chain;
		my $qscore;
		my $file;

		## Accounting for variation between data structures between RCSB and PFAM matches
		if ($rcsb){
			$pdb_code = lc($data[2]);
			$chain = $data[3];
			$qscore = $data[4];
		}
		elsif ($pfam){
			$chain = $data[2];
			$qscore = $data[3];
			$file = $data[8];
			$file =~ s/.pdb//;
		}

		## Printing information
		if ($qscore >= $qthreshold){
			if ($best){
				if ($best >= $hit_number){
					if ($rcsb){
						print OUT "$prefix\t";
						for (1..$#data){ print OUT "$data[$_]\t"; }
						print OUT "$rcsb_titles{$pdb_code}{$chain}\n";
					}
					elsif ($pfam){
						print OUT "$prefix\t";
						for (1..$#data){ print OUT "$data[$_]\t"; }
						print OUT "$pfam_titles{$file}\n";
					}
				}
			}
			else {
				if ($rcsb){
					print OUT "$prefix\t";
					for (1..$#data){ print OUT "$data[$_]\t"; }
					print OUT "$rcsb_titles{$pdb_code}{$chain}\n";
				}
				elsif ($pfam){
					if(exists $pfam_titles{$file}){
						print OUT "$prefix\t";
						for (1..$#data){ print OUT "$data[$_]\t"; }
						print OUT "\t$pfam_titles{$file}\n";
					}
					else {
						print LOG "\nFile $file.pdb has no match in PFAM clan file\n\n";
					}
				}
			}
		}
	}
}