#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.5b';
my $name = 'descriptive_GESAMT_matches.pl';
my $updated = '2021-04-21';

use strict; use warnings; use Getopt::Long qw(GetOptions);

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
-p (--pfam)	Tab-delimeted list of PFAM stuctures and their titles (http://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz)
-m (--matches)	Results from GESAMT searches ## see run_GESAMT.pl
-q (--qscore)	Q-score cut-off [Default: 0.3]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: Gesamt.matches]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $rcsb;
my $pfam;
my @matches;
my $qthreshold = 0.3;
my $best;
my $output = 'GESAMT.matches';
GetOptions(
	'r|rcsb=s' => \$rcsb,
	'p|pfam=s' => \$pfam,
	'm|matches=s@{1,}' => \@matches,
	'q|qscore=s' => \$qthreshold,
	'b|best=i' => \$best,
	'o|output=s' => \$output
);

open LOG, ">", "$name.log";

my %db_titles;
if ($rcsb){
	## Creating a database of RSCB stuctures and their descriptions; PDB 4-letter code => description
	open DB, "<", "$rcsb" or die "Can't open tab-delimited file $rcsb: $!\n";
	while (my $line = <DB>){
		chomp $line;
		if ($line =~ /^(\S+)\t(.*)$/){
			my $key = uc($1);
			$db_titles{$key} = $2;
		}
	}
}
elsif ($pfam){
	## Creating a database of PFAM structures and their descriptions; PFAM 5-number code => description
	open DB, "<", "$pfam" or die "Can't open tab-delimited file $pfam: $!\n";
	while (my $line = <DB>){
		chomp $line;
		my @data = split("\t",$line);
		$db_titles{$data[0]} = $data[4];
	}
}

## Iterating through Gesamt matches
open OUT, ">", "$output" or die "Can't create output file $output: $!\n";
my $total_matches = scalar(@matches);
while (my $match = shift@matches){
	system "clear";
	my $remaining = "." x (int((scalar(@matches)/$total_matches)*100));
	my $progress = "|" x (100-int((scalar(@matches)/$total_matches)*100));
	my $status = "[".$progress.$remaining."]";
	print("Getting match descriptions\n");
	print("\n\t$status\t".($total_matches-scalar(@matches))."/$total_matches\n");
	open MA, "<", "$match" or die "Can't read file $match: $!\n";
	my ($prefix, $suffix) = $match =~ /^(\S+)\.(\w+.gesamt)$/;
	print OUT '### '."$prefix\n";

	while (my $line = <MA>){
		chomp $line;
		my @data = split(/\s+/,$line);

		if($line =~ /^#/){
			next;
		}

		my $hit_number = $data[1];
		my $pdb_code;
		my $chain;
		my $qscore;
		my $file;
		
		if($rcsb){
			$pdb_code = $data[2];
			$chain = $data[3];
			$qscore = $data[4];
		}
		elsif ($pfam){
			$chain = $data[2];
			$qscore = $data[3];
			$file = $data[8];
			$file =~ s/.pdb//;
		}

		if ($qscore >= $qthreshold){
			if ($best){
				if ($best >= $hit_number){
					if($rcsb){
						print OUT "$prefix\t$line\t$db_titles{$pdb_code}\n";
					}
					elsif($pfam){
						print OUT "$prefix\t$line\t$db_titles{$file}\n";
					}
				}
			}
			else { 
				if($rcsb){
					print OUT "$prefix\t$line\t$db_titles{$pdb_code}\n";
				}
				elsif($pfam){
					if(exists $db_titles{$file}){
						print OUT "$prefix\t$line\t$db_titles{$file}\n";
					}
					else{
						print LOG "\nFile $file.pdb has no match in PFAM clan file\n\n";
					}
				}
			}
		}
	}
}