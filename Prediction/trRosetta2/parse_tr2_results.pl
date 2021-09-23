#!/usr/bin/perl
## Pombert lab, Illinois Tech, 2021
my $name = 'parse_tr2_results';
my $version = '0.1';
my $updated = '2021-08-04';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);

my $usage =<<"OPTIONS";
NAME		${name}
VERSION		${version}
UDPATED		${updated}
SYNOPSIS	Parses the trRosetta2 results and rename the outputs with the protein names.

EXAMPLE		${name} \\
		  -r trRosetta2_results/ \\
		  -o Parsed_results \\
		  -t 1

OPTIONS:
-r (--r2dir)	trRosetta2 output directory
-o (--outdir)	Parsed output directory
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
OPTIONS
die "\n$usage\n" unless @ARGV;

my $r2dir;
my $outdir;
my $top = 1;
my $verbosity;
GetOptions(
	'r|r2dir=s' => \$r2dir,
	'o|outdir=s' => \$outdir,
	't|top=i' => \$top,
	'v|verbosity' => \$verbosity
);

## Checking number of pdb templates requested
if ($top > 5){
	die "\nPlease enter a number between 1 and 5. RoseTTAFold generates a total of 5 models.\n\n";
}

## Parsing files
opendir (DIR, $r2dir) or die "Can't open trRosetta2 folder $r2dir: $!\n";
my @results;
if ($verbosity) { print "\n"; }
while (my $subfolder = readdir(DIR)) {
	if (-d "$r2dir/$subfolder"){
		unless ( ($subfolder eq '.') or ($subfolder eq '..') ){
			if ($verbosity) { print "Found subfolder: $subfolder\n"; }
			push (@results, $subfolder);
		}
	}
}
if ($verbosity) { print "\n"; }

## Check output directory
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n" ; }

while (my $result = shift @results){
	
	my $filename = "$r2dir/$result/model/model_1.crderr.pdb";

	unless (-f $filename){
		print "$result: $filename not found. Check if the folding completed properly\n";
		next;
	}
	else {
		for my $num (1..$top){ 
			$filename = "$r2dir/$result/model/model_$num.crderr.pdb";
			if (-f $filename) {
				system "cp $filename $outdir/$result-m$num.pdb";
			}
		}
	}
}