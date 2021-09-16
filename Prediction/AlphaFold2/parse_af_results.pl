#!/usr/bin/perl
## Pombert lab, Illinois Tech, 2021
my $name = 'parse_af_results';
my $version = '0.4';
my $updated = '2021-09-07';

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
		  -t 1 \\
		  -s

OPTIONS:
-a (--afdir)	AlphaFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	ranked (k), relaxed (r), unrelaxed (u), all (a) [Default: k]
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-s (--standard)	Uses standardized model names (-m1 to -m5) instead of -r0 to -r4 for ranked PDB files 
-v (--verbose)	Adds verbosity
OPTIONS
die "\n$usage\n" unless @ARGV;

my $afdir;
my $outdir;
my $pdbtype = 'k';
my $standard;
my $top = 1;
my $verbosity;
GetOptions(
	'a|afdir=s' => \$afdir,
	'o|outdir=s' => \$outdir,
	'p|pdbtype=s' => \$pdbtype,
	's|standard' => \$standard,
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

my $result;
while ($result = shift @results){
	
	## Ranked models
	if (($pdbtype eq 'k') or ($pdbtype eq 'ranked')){ pdb_out('ranked', 'k', 1); }

	## Relaxed models
	elsif (($pdbtype eq 'r') or ($pdbtype eq 'relaxed')){ pdb_out('relaxed_model', 'r', 0); }

	## Unrelaxed models
	elsif (($pdbtype eq 'u') or ($pdbtype eq 'unrelaxed')){	pdb_out('unrelaxed_model', 'u', 0); }

	## All models
	elsif (($pdbtype eq 'a') or ($pdbtype eq 'all')){
		pdb_out('ranked', 'k', 1); ## Ranked
		pdb_out('relaxed_model', 'r', 0); ## Relaxed
		pdb_out('unrelaxed_model', 'u', 0); ## Unrelaxed
	}
	
	## If unrecognized command line: 
	else { die "\nUnrecognized pdbtype: please enter ranked (k), relaxed (r), unrelaxed (u), or all (a)\n\n"; }

}

### Subroutine
sub pdb_out {

	my ($model_name, $moniker, $phase) = @_;

	for my $num (1-$phase..$top-$phase){

		## Original PDB name in AlphaFold folder
		my $original_pdb = "$afdir/$result/${model_name}_$num.pdb";

		## Checking for standardization flag for ranked files
		unless (($moniker eq 'r') or ($moniker eq 'u')){
			if ($standard){ 
				$num++;
				$moniker = 'm';
			}
		}

		## Output file name		
		my $out_pdb = "$outdir/$result-${moniker}${num}.pdb";
		if (-f $original_pdb){
			unless (-f $out_pdb){ system "cp $original_pdb $out_pdb"; }
		}
		else {
			print STDERR "Error: $original_pdb not found. Check if folding of $result completed correctly.\n";
		}

		if ($verbosity){
			print "Copying $original_pdb => $out_pdb\n";
		}

	}
}