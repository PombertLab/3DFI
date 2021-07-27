#!/usr/bin/perl
## Pombert lab, Illinois Tech, 2021
my $name = 'parse_af_results';
my $version = '0.2a';
my $updated = '2021-07-22';

use strict; use warnings; use Getopt::Long qw(GetOptions);

my $usage =<<"OPTIONS";
NAME		${name}
VERSION		${version}
UDPATED		${updated}
SYNOPSIS	Parses the AlphaFold results and rename the outputs with the protein names.

EXAMPLE		${name} \\
		  -a AlphaFold2_results/ \\
		  -o Parsed_results \\
		  -p k \\
		  -t 1

OPTIONS:
-a (--afdir)	AlphaFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	ranked (k), relaxed (r), unrelaxed (u), all (a) [Default: k]
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
OPTIONS
die "\n$usage\n" unless @ARGV;

my $afdir;
my $outdir;
my $pdbtype = 'k';
my $top = 1;
my $verbosity;
GetOptions(
	'a|afdir=s' => \$afdir,
	'o|outdir=s' => \$outdir,
	'p|pdbtype=s' => \$pdbtype,
	't|top=i' => \$top,
	'v|verbosity' => \$verbosity
);

## Checking number of pdb templates requested
if ($top > 5){
	die "\nPlease enter a number between 1 and 5. AlphaFold2 generates a total of 5 models.\n\n";
}

## Setting to lowercase to prevent possible typos
$pdbtype = lc($pdbtype);

## Check output directory
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n" ; }

## Parsing files
opendir (DIR, $afdir) or die "Can't open AlphaFold2 folder $afdir: $!\n";
my @results;
if ($verbosity) { print "\n"; }
while (my $subfolder = readdir(DIR)) {
	if (-d "$afdir/$subfolder"){
		unless ( ($subfolder eq '.') or ($subfolder eq '..') ){
			if ($verbosity) { print "Found subfolder: $subfolder\n"; }
			push (@results, $subfolder);
		}
	}
}
if ($verbosity) { print "\n"; }

while (my $result = shift @results){
	
	## Ranked models
	if (($pdbtype eq 'k') or ($pdbtype eq 'ranked')){
		for my $num (0..$top-1){
			my $ranked = "$afdir/$result/ranked_$num.pdb";
			if (-f $ranked){
				system "cp $ranked $outdir/$result-k$num.pdb";
			}
			else {
				print STDERR "Error: $ranked not found. Check if folding of $result completed correctly.\n";
			}
		}
	}

	## Relaxed models
	elsif (($pdbtype eq 'r') or ($pdbtype eq 'relaxed')){
		for my $num (1..$top){ 
			my $relaxed = "$afdir/$result/relaxed_model_$num.pdb";
			if (-f $relaxed){
				system "cp $relaxed $outdir/$result-r$num.pdb";
			}
			else {
				print STDERR "Error: $relaxed not found. Check if folding of $result completed correctly.\n";
			}
		}
	}

	## Unrelaxed models
	elsif (($pdbtype eq 'u') or ($pdbtype eq 'unrelaxed')){
		for my $num (1..$top){
			my $unrelaxed = "$afdir/$result/unrelaxed_model_$num.pdb";
			if (-f $unrelaxed){
				system "cp $unrelaxed $outdir/$result-u$num.pdb";
			}
			else {
				print STDERR "Error: $unrelaxed not found. Check if folding of $result completed correctly.\n";
			}
		}
	}

	## All models
	elsif (($pdbtype eq 'a') or ($pdbtype eq 'all')){

		## Ranked
		for my $num (0..$top-1){ 
			my $ranked = "$afdir/$result/ranked_$num.pdb";
			if (-f $ranked){
				system "cp $ranked $outdir/$result-k$num.pdb";
			}
			else {
				print STDERR "Error: $ranked not found. Check if folding of $result completed correctly.\n";
			}
		}

		## Relaxed
		for my $num (1..$top){ 
			my $relaxed = "$afdir/$result/relaxed_model_$num.pdb";
			if (-f $relaxed){
				system "cp $relaxed $outdir/$result-r$num.pdb";
			}
			else {
				print STDERR "Error: $relaxed not found. Check if folding of $result completed correctly.\n";
			}
		}

		## Unrelaxed
		for my $num (1..$top){
			my $unrelaxed = "$afdir/$result/unrelaxed_model_$num.pdb";
			if (-f $unrelaxed){
				system "cp $unrelaxed $outdir/$result-u$num.pdb";
			}
			else {
				print STDERR "Error: $unrelaxed not found. Check if folding of $result completed correctly.\n";
			}
		}
	
	}
	
	## If unrecognized command line: 
	else { die "\nUnrecognized pdbtype: please enter ranked (k), relaxed (r), unrelaxed (u), or all (a)\n\n"; }

}