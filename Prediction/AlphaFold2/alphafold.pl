#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'alphafold.pl';
my $version = '0.3a';
my $updated = '2021-09-05';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use POSIX qw(strftime);
use Cwd qw(abs_path);

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs AlphaFold2 from Google Deepmind in batch mode
REQUIREMENTS	AlphaFold2: https://github.com/deepmind/alphafold

EXAMPLE     ${name} \\
		  -f *.fasta \\
		  -o ALPHAFOLD_3D/ \\
		  -m 2021-01-21 \\
		  -c \\
		  -ah /opt/alphafold \\
		  -ao /media/Data_1/alphafold_results

OPTIONS:
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-m (--max_date)		--max_template_date option (YYYY-MM-DD) from AlphaFold2 [Default: current date]
-p (--preset)		Alphafold preset: full_dbs, reduced_dbs or casp14 [Default: full_dbs]
-g (--gpu_dev)		List of GPU devices to use: e.g. all; 0,1; 0,1,2,3 [Default: all]
-n (--no_gpu)		Turns off GPU acceleration
-ah (--alpha_home)	AlphaFold2 installation directory
-ao (--alpha_out)	AlphaFold2 output directory

NOTE:	The -ia and -ao options are not required if the environment variables \$ALPHAFOLD_HOME and \$ALPHAFOLD_OUT are set, e.g.:
	export ALPHA_HOME=/opt/alphafold
OPTIONS
die "\n$usage\n" unless @ARGV;
my @command = @ARGV;

my @fasta;
my $outdir = './';
my $max_date = strftime("%F", localtime);
my $preset = 'full_dbs';
my $gpus = 'all';
my $no_gpu;
my $alpha_home;
my $alpha_out;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|outdir=s' => \$outdir,
	'm|max_date=s' => \$max_date,
	'p|preset=s' => \$preset,
	'g|gpu_dev=s' => $gpus,
	'n|no_gpu' => \$no_gpu,
	'ah|alpha_home=s' => \$alpha_home,
	'ao|alpha_out=s' => \$alpha_out
);

### Checking for AlphaFold2 installation; environment variables in Perl are loaded in %ENV
# Checking installation folder
if (!defined $alpha_home){
	if (exists $ENV{'ALPHAFOLD_HOME'}){ $alpha_home = $ENV{'ALPHAFOLD_HOME'}; }
	else {
		print "WARNING: The AlphaFold2 installation directory is not set as an environment variable (\$ALPHAFOLD_HOME) and the -ah option was not entered.\n";
		print "Please check if AlphaFold2 was installed properly\n\n";
		exit;
	}
}
elsif (defined $alpha_home){
	unless (-d $alpha_home){ die "WARNING: Can't find AlphaFold2 installation folder: $alpha_home. Please check command line\n\n"; }
	else {
		unless (-r $alpha_home){ die "WARNING: Can't read the content of AlphaFold2 installation folder: $alpha_home. Please check file permissions\n\n"; }
	}
}
# Checking output folder
if (!defined $alpha_out){
	if (exists $ENV{'ALPHAFOLD_OUT'}){ $alpha_out = $ENV{'ALPHAFOLD_OUT'}; }
	else {
		print "WARNING: The AlphaFold2 output directory is not set as an environment variable (\$ALPHAFOLD_OUT) and the -ao option was not entered.\n";
		print "Please check if AlphaFold2 was installed properly\n\n";
		exit;
	}
}
elsif (defined $alpha_out){
	unless (-d $alpha_out){	die "WARNING: Can't find AlphaFold2 output folder: $alpha_out. Please check command line\n\n"; }
	else {
		unless (-r $alpha_out){ die "WARNING: Can't read the content of AlphaFold2 output folder: $alpha_out. Please check file permissions\n\n"; }
	}
}

### Checking AlphaFold2 preset
my %presets = (
	full_dbs => '',
	reduced_dbs => '',
	casp14 => ''
);
unless (exists $presets{$preset}){
	die "Unrecognized AlphaFold2 preset. Please use full_dbs, reduced_dbs, or casp14\n";
}

### Checking output directory + creating log file
$outdir = abs_path($outdir);
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n"; }
open LOG, ">>", "$outdir/alphafold2.log" or die "Can't create $outdir/alphafold2.log: $!\n";

my $timestamp = localtime;
print LOG "\nCOMMAND = $name @command\n";
print LOG "\nFolding started on $timestamp\n";
print LOG "\nSetting AlphaFold2 --max_template_date option to: $max_date\n\n";
print "\nSetting AlphaFold2 --max_template_date option to: $max_date\n";

### Running AlphaFold2 docker image
while (my $fasta = shift @fasta){

	my $basename = fileparse($fasta);
	my ($prefix) = $basename =~ /^(.*)\.\w+$/;

	## Checking if protein structures are already present in output dir
	if (-f "$outdir/$prefix/ranked_0.pdb"){
		print "AlphaFold predicted structure (ranked_0.pdb) found for $basename. Skipping folding...\n";
		next;
	}
	else {
		# Timestamp
		my $time = localtime;
		print "\n$time: working on $fasta\n";
		my $start = time;

		my $gpu_devices = "--gpu_devices=$gpus";

		my $gpu_check = '';
		if ($no_gpu){
			$gpu_check = '--use_gpu=False';
			$gpu_devices = '';
		}

		# Folding
		system "python3 \\
			$alpha_home/docker/run_docker.py \\
			--fasta_paths=$fasta \\
			--max_template_date=$max_date \\
			--preset=$preset \\
			$gpu_devices \\
			$gpu_check
		";

		# Checking permissions:
		# if docker image is ran with --privileged=True files will be owned by the root
		# if so, use cp instead of mv
		
		exit;

		if (-w "$alpha_out/$prefix"){
			system "mv \\
				$alpha_home/$prefix \\
				$outdir/";
		}
		else { # Copying results to outdir
			system "cp -R \\
				$alpha_out/$prefix \\
				$outdir/";
		}

		my $run_time = time - $start;
		$run_time = $run_time/60;
		$run_time = sprintf ("%.2f", $run_time);
		print "\nTime to fold $basename: $run_time minutes\n";
		print LOG "Time to fold $basename: $run_time minutes\n";
	}
}

close LOG;