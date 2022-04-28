#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'parse_all_models_by_Q.pl';
my $version = '0.2';
my $updated = '2022-04-27';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;

my $usage = <<"USAGE";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Parses the output of descriptive_GESAMT_matches.pl per protein accross all models,
		from best Q-score to worst.

EXAMPLE		${name} \\
		  -a gesamt \\
		  -m *_GESAMT_per_model.matches \\
		  -o All_GESAMT_matches_per_protein.tsv \\
		  -x 50

GENERAL OPTIONS:
-a (--align)	Alignment tool: gesamt or foldseek [Default: gesamt]
-m (--matches)	Foldseek/GESAMT matches parsed by descriptive_matches.pl
-o (--out)	Output file in TSV format [Default: All_GESAMT_matches_per_protein.tsv]
-x (--max)	Max number of distinct RCSB/chain hits to keep [Default: 50]
-r (--redun)	Keep all entries for redundant RCSB chains [Default: off]
-w (--word)	Use word regular expression (\\w+) to capture locus tag [Default: off]
USAGE
die "\n$usage\n" unless @ARGV;

my $aligner = 'gesamt';
my @matches;
my $outfile = 'All_GESAMT_matches_per_protein.tsv';
my $max = 50;
my $redundancy;
my $word;
GetOptions(
	'a|align=s' => \$aligner,
	'm|matches=s@{1,}' => \@matches,
	'o|out=s' => \$outfile, 
	'x|max=i' => \$max,
	'r|redun' => \$redundancy,
	'w|word' => \$word
);

## Output file
open OUT, ">", "$outfile" or die "Can't create $outfile: $!\n";


## ## Store proteins and corresponding matches in a single database
my %proteins; 
while (my $file = shift@matches){
	open IN, "<", "$file";
	
	## Grabbing the predictor used from the filename
	my $filename = fileparse($file);
	my $predictor;
	if ($aligner eq 'gesamt'){
		($predictor) = $filename =~ /^(\w+)_GESAMT_per_(\w+).matches/;
	}
	elsif ($aligner eq 'foldseek'){
		($predictor) = $filename =~ /^(\w+)_FOLDSEEK_per_(\w+).matches/;
	}

	## 
	while (my $line = <IN>){
		chomp $line;
		if ($line =~ /^#/){ next; }
		elsif ($line eq ''){ next; }
		else {
			my @data = split ("\t", $line);
			my $protein;
			if ($word){ ($protein) = $data[0] =~ /^(\w+)/; }
			else { ($protein) = $data[0] =~ /^(\S+)\-\w\d+$/; }
			
			## Tagging the line with the predictor used
			my $newline = $line."\t"."$predictor";
			
			## Add line to @array containing all matches found for the corresponding protein
			push (@{$proteins{$protein}}, $newline);
		}
	}
}

## Iterating through all proteins
for my $protein (sort (keys %proteins)){
	
	my %rcsb_matches;
	my $hit_counter;

	print OUT "\n### $protein; Top matches across all predictors. Sorted by quality scores: ";
	if ($redundancy){ print OUT "duplicated RCSB PDB entries (if any) are shown\n"; }
	else { print OUT "duplicated RCSB PDB entries are not shown\n"; }

	## Sorting by column
	my @sorted_matches;
	if ($aligner eq 'gesamt'){
		## Q-score is located in column #5
		@sorted_matches = sort { (split("\t", $b))[4] <=> (split("\t", $a))[4] } @{$proteins{$protein}};
	}
	if ($aligner eq 'foldseek'){
		## Q-score is located in column #12
		@sorted_matches = sort { (split("\t", $b))[11] <=> (split("\t", $a))[11] } @{$proteins{$protein}};
	}

	while (my $line = shift@sorted_matches){
		
		my @data = split ("\t", $line);
		my $predictor = pop(@data);
		my $rcsb_id;
		my $rcsb_chain;
		if ($aligner eq 'gesamt'){
			$rcsb_id = $data[2];
			$rcsb_chain = $data[3];
		}
		elsif ($aligner eq 'foldseek'){
			if ($data[1] =~ /^pdb(\w{4}).ent.gz_(\S+)$/){
				$rcsb_id = $1;
				$rcsb_chain = $2;
			}
			elsif ($data[1] =~ /^pdb(\w{4}).ent.gz$/){
				$rcsb_id = $1;
				$rcsb_chain = 'A';
			}
		}

		## Adding chain to RCSB tag, a unique ID often contain more than one protein or chain
		my $rcsb_key = "$rcsb_id".'_'."$rcsb_chain";

		if ($aligner eq 'gesamt'){
			## Replacing uninformative column by $predictor
			$data[1] = $predictor;
		}
		if ($aligner eq 'foldseek'){
			## Adding $predictor to @data with splice
			splice (@data, 1, 0, $predictor);
		}

		if ($redundancy){ ## Keeping redundant RCSB tag + chain if redundancy is wanted
			$rcsb_matches{$rcsb_key} = '';
			$hit_counter += 1;
		}
		else { ## Checking if the same RCSB tag + chain if found, if so skip
			if (exists $rcsb_matches{$rcsb_key}){ next; }
			else {
				$rcsb_matches{$rcsb_key} = '';
				$hit_counter += 1;
			}
		}

		if ($hit_counter <= $max){
			for (0..$#data-1){ print OUT "$data[$_]\t";}
			print OUT "$data[$#data]\n";
		}
	}
}
