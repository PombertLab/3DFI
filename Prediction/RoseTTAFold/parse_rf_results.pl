#!/usr/bin/perl
## Pombert lab, Illinois Tech, 2021
my $name = 'parse_rf_results';
my $version = '0.2';
my $updated = '2021-08-12';

use strict; use warnings; use Getopt::Long qw(GetOptions);

my $usage =<<"OPTIONS";
NAME		${name}
VERSION		${version}
UDPATED		${updated}
SYNOPSIS	Parses the RoseTTAFold results and rename the outputs with the protein names.

EXAMPLE		${name} \\
		  -a RoseTTAFold_results/ \\
		  -o Parsed_results \\
		  -p e2e \\
		  -t 1

OPTIONS:
-r (--rfdir)	RoseTTAFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	PDB type: pyrosetta (py) or end-to-end (e2e) [Default: e2e]
-t (--top)	Top X number of pdb files to keep for pyrosetta PDBs, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
OPTIONS
die "\n$usage\n" unless @ARGV;

my $rfdir;
my $outdir;
my $pdbtype = 'e2e';
my $top = 1;
my $verbosity;
GetOptions(
	'r|rfdir=s' => \$rfdir,
	'o|outdir=s' => \$outdir,
	'p|pdbtype=s' => \$pdbtype,
	't|top=i' => \$top,
	'v|verbosity' => \$verbosity
);

## Checking number of pdb templates requested
if ($top > 5){
	die "\nPlease enter a number between 1 and 5. RoseTTAFold generates a total of 5 models.\n\n";
}

## Setting to lowercase to prevent possible typos
$pdbtype = lc($pdbtype);

## Check output directory
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n" ; }

## Parsing files
opendir (DIR, $rfdir) or die "Can't open RoseTTAFold folder $rfdir: $!\n";
my @results;
if ($verbosity) { print "\n"; }
while (my $subfolder = readdir(DIR)) {
	if (-d "$rfdir/$subfolder"){
		unless ( ($subfolder eq '.') or ($subfolder eq '..') ){
			if ($verbosity) { print "Found subfolder: $subfolder\n"; }
			push (@results, $subfolder);
		}
	}
}
if ($verbosity) { print "\n"; }

while (my $result = shift @results){
	
	## e2e
	if (($pdbtype eq 'e2e') or ($pdbtype eq 'end-to-end')){

		my $filename = "$rfdir/$result/t000_.e2e.pdb";
		my $outfile = "$outdir/$result.pdb";

		if (-f "$filename"){ 
			unless (-f $outfile) { system "cp $filename $outfile"; }
		}
		else {
			print "$result: No PDB file found. ";
			print "Check for possible video RAM issue ('RuntimeError: CUDA out of memory') in $rfdir/$result/log/network.stderr.\n";
		}
	}
	## pyrosetta
	elsif (($pdbtype eq 'py') or ($pdbtype eq 'pyrosetta')){
		for my $num (1..$top){ 

			my $filename = "$rfdir/$result/model/model_$num.crderr.pdb";
			my $outfile = "$outdir/$result-m$num.pdb";

			unless (-f $outfile) { system "cp $filename $outfile"; }
		}
	}
	## If unrecognized command line: 
	else { die "\nUnrecognized pdbtype: please enter end-to-end (e2e) or pyrosetta (py).\n\n"; }

}