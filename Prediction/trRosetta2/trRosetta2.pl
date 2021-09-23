#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'trRosetta2.pl';
my $version = '0.1';
my $updated = '2021-08-04';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs trRosetta2 from in batch mode

REQUIREMENTS	trRosetta2 - https://github.com/RosettaCommons/trRosetta2
		PyRosetta - https://www.pyrosetta.org/
		Conda - https://docs.conda.io/en/latest/

EXAMPLE		${name} \\
		  -f *.fasta \\
		  -o TROS2_3D/ \\
		  -g

OPTIONS:
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-g (--gpu)		Uses GPU acceleration (>= 16 Gb video RAM recommended); defaults to CPU otherwize
-t (--trrosetta2)	trRosetta2 installation directory

NOTES:
- The -t option is not required if the environment variable \$TRROSETTA2_HOME is set, e.g.:
  export TRROSETTA2_HOME=/opt/trRosetta2
OPTIONS
die "\n$usage\n" unless @ARGV;
my @command = @ARGV;

my @fasta;
my $outdir;
my $gpu;
my $trrosetta2_home;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|outdir=s' => \$outdir,
	'g|gpu' => \$gpu,
	't|trrosetta2=s' => \$trrosetta2_home,
);

### Checking for RoseTTAFold installation; environment variables in Perl are loaded in %ENV
# Checking installation folder
if (!defined $trrosetta2_home){
	if (exists $ENV{'TRROSETTA2_HOME'}){ $trrosetta2_home = $ENV{'TRROSETTA2_HOME'}; }
	else {
		print "WARNING: The trRosetta2 installation directory is not set as an environment variable (\$TRROSETTA2_HOME) and the -t option was not entered.\n";
		print "Please check if trRosetta2 was installed properly\n\n";
		exit;
	}
}
elsif (defined $trrosetta2_home){
	unless (-d $trrosetta2_home){ die "WARNING: Can't find trRosetta2 installation folder: $trrosetta2_home. Please check command line\n\n"; }
}

## Check output directory + creating log file
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n"; }
open LOG, ">>", "$outdir/trRosetta2.log" or die "Can't create $outdir/trRosetta2.log: $!\n";;

my $timestamp = localtime;
print LOG "\nCOMMAND = $name @command\n";
print LOG "\nFolding started on $timestamp\n";

## Running trRosetta2 on FASTA files
while (my $fasta = shift@fasta){

	my $basename = fileparse($fasta);
	my ($prefix) = $basename =~ /^(.*)\.\w+$/;

	## Checking if protein structures are already present in output dir
	if (-f "$outdir/$prefix/model/model_5.crderr.pdb"){
		print "\nPDB output found for $basename. Skipping folding...\n";
		next;
	}

	else {
		my $time = localtime;
		print "\n$time: Working on $fasta...\n";
		my $start = time;

		## Running with GPU if flag is on
		if ($gpu){
			system "$trrosetta2_home/run_pipeline.sh \\
				$fasta \\
				$outdir/$prefix";
		}
		## Defaulting to cpu otherwise
		else {
			system "$trrosetta2_home/run_pipeline_cpu.sh \\
				$fasta \\
				$outdir/$prefix";
		}

		my $run_time = time - $start;
		$run_time = $run_time/60;
		$run_time = sprintf ("%.2f", $run_time);
		print "\nTime to fold $basename: $run_time minutes\n";
		print LOG "Time to fold $basename: $run_time minutes\n";
	}
}
