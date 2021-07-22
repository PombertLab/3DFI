#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'rosettafold.pl';
my $version = '0.1';
my $updated = '2021-07-22';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs RoseTTAFold from in batch mode
REQUIREMENTS	RoseTTAFold: https://github.com/RosettaCommons/RoseTTAFold
			PyRosetta: https://www.pyrosetta.org/
			Conda: https://docs.conda.io/en/latest/

EXAMPLE     ${name} \\
		  -f *.fasta \\
		  -o RFOLD_3D/ \\
		  -t py

OPTIONS:
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-t (--type)		Folding type: pyrosetta (py) or end-to-end (e2e)  [Default: e2e]
-r (--rosetta)		RoseTTAFold installation directory

NOTES:
- The e2e option requires a GPU with > 8 Gb RAM to tackle larger proteins; pyrosetta is slower but not video RAM constrained
- The -r option is not required if the environment variable \$ROSETTAFOLD_HOME is set, e.g.:
export ROSETTAFOLD_HOME=/opt/RoseTTAFold
OPTIONS
die "\n$usage\n" unless @ARGV;
my @command = @ARGV;

my @fasta;
my $outdir;
my $folding_type = 'e2e';
my $rosetta_home;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|outdir=s' => \$outdir,
	't|type=s' => \$folding_type,
	'r|rosetta=s' => \$rosetta_home,
);

$folding_type = lc($folding_type);

### Checking for RoseTTAFold installation; environment variables in Perl are loaded in %ENV
# Checking installation folder
if (!defined $rosetta_home){
	if (exists $ENV{'ROSETTAFOLD_HOME'}){ $rosetta_home = $ENV{'ROSETTAFOLD_HOME'}; }
	else {
		print "WARNING: The RoseTTAFold installation directory is not set as an environment variable (\$ROSETTAFOLD_HOME) and the -r option was not entered.\n";
		print "Please check if RoseTTAFold was installed properly\n\n";
		exit;
	}
}
elsif (defined $rosetta_home){
	unless (-d $rosetta_home){ die "WARNING: Can't find RoseTTAFold installation folder: $rosetta_home. Please check command line\n\n"; }
}

## Check output directory + creating log file
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n"; }
open LOG, ">>", "$outdir/rosettafold.log" or die "Can't create $outdir/rosettafold.log: $!\n";;

my $timestamp = localtime;
print LOG "\nCOMMAND = $name @command\n";
print LOG "\nFolding started on $timestamp\n";

## Running RoseTTAFold on FASTA files
while (my $fasta = shift@fasta){

	my $basename = fileparse($fasta);
	my ($prefix) = $basename =~ /^(.*)\.\w+$/;

	## Checking if protein structures are already present in output dir
	if (-f "$outdir/$prefix/t000_.e2e.pdb"){
		print "\nPDB output found for $basename. Skipping folding...\n";
		next;
	}

	else {
		my $time = localtime;
		print "\n$time: Working on $fasta...\n";
		my $start = time;

		if (($folding_type eq 'py') or ($folding_type eq 'pyrosetta')){
			system "$rosetta_home/run_pyrosetta_ver.sh \\
				$fasta \\
				$outdir/$prefix";
		}
		elsif (($folding_type eq 'e2e') or ($folding_type eq 'end-to-end')){
			system "$rosetta_home/run_e2e_ver.sh \\
				$fasta \\
				$outdir/$prefix";
		}
		else {
			die "\nUnrecognized folding type: $folding_type. Please check command line.\n\n";
		}

		my $run_time = time - $start;
		$run_time = $run_time/60;
		$run_time = sprintf ("%.2f", $run_time);
		print "\nTime to fold $basename: $run_time minutes\n";
		print LOG "Time to fold $basename: $run_time minutes\n";
	}
}
