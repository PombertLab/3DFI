#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'alphafold.pl';
my $version = '0.6'; ## Updated to match Alphafold 2.1.1 cmd line switches
my $updated = '2022-05-25';

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

REQUIREMENTS	AlphaFold2: https://github.com/PombertLab/alphafold

CITATION	If you use AlphaFold2, please cite the original authors:
		Jumper et al. Highly accurate protein structure prediction with AlphaFold.
		Nature. 2021. 596(7873):583-589. DOI: 10.1038/s41586-021-03819-2

EXAMPLE     ${name} \\
		  -f *.fasta \\
		  -o ALPHAFOLD_3D/ \\
		  -m 2021-01-21 \\
		  -c

OPTIONS:
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-d (--docker)		Docker image name [Default: alphafold_3dfi]
-m (--max_date)		--max_template_date option (YYYY-MM-DD) from AlphaFold2 [Default: current date]
-p (--preset)		Alphafold --db_preset: full_dbs or reduced_dbs [Default: full_dbs]
-u (--use_msas)		Use precomputed MSAs
-g (--gpu_dev)		List of GPU devices to use: e.g. all; 0,1; 0,1,2,3 [Default: all]
-n (--no_gpu)		Turns off GPU acceleration
-ah (--alpha_home)	AlphaFold2 installation directory [Default: \$ALPHAFOLD_HOME]
-ad (--alpha_db)	AlphaFold2 databases location [Default: \$TDFI_DB/ALPHAFOLD]
OPTIONS
die "\n$usage\n" unless @ARGV;
my @command = @ARGV;

my @fasta;
my $outdir = './';
my $docker_image_name = 'alphafold_3dfi';
my $max_date = strftime("%F", localtime);
my $preset = 'full_dbs';
my $precomputed_msas;
my $gpus = 'all';
my $no_gpu;
my $alpha_home;
my $alpha_db;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|outdir=s' => \$outdir,
	'd|docker=s' => \$docker_image_name,
	'm|max_date=s' => \$max_date,
	'p|preset=s' => \$preset,
	'u|use_msas' => \$precomputed_msas,
	'g|gpu_dev=s' => \$gpus,
	'n|no_gpu' => \$no_gpu,
	'ah|alpha_home=s' => \$alpha_home,
	'ad|alpha_db=s' => \$alpha_db
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
# Checking AlphaFold2 database folder
if (!defined $alpha_db){
	if (exists $ENV{'TDFI_DB'}){ $alpha_db = "$ENV{'TDFI_DB'}".'/'.'ALPHAFOLD'; }
	else {
		print "WARNING: The 3DFI database folder is not set as an environment variable (\$TDFI_DB) and the -ad option was not entered.\n";
		print "Please check if AlphaFold2 databases were installed properly\n\n";
		exit;
	}
}
elsif (defined $alpha_db){
	unless (-d $alpha_db){ die "WARNING: Can't find AlphaFold2 database folder: $alpha_db. Please check command line\n\n"; }
	else {
		unless (-r $alpha_db){ die "WARNING: Can't read the content of AlphaFold2 database folder: $alpha_db. Please check file permissions\n\n"; }
	}
}

### Checking AlphaFold2 preset
my %presets = (
	full_dbs => '',
	reduced_dbs => ''
);
unless (exists $presets{$preset}){
	die "Unrecognized AlphaFold2 preset. Please use full_dbs or reduced_dbs\n";
}

### Checking output directory + creating log file
$outdir = abs_path($outdir);
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n"; }
open LOG, ">>", "$outdir/alphafold2.log" or die "Can't create $outdir/alphafold2.log: $!\n";

my $timestamp = localtime;
print LOG "\nCOMMAND = $name @command\n";
print LOG "\nFolding started on $timestamp\n";
print LOG "\nSetting AlphaFold2 --max_template_date option to: $max_date\n\n";
print "\nSetting AlphaFold2 options --db_preset to $preset, --max_template_date to $max_date, and --docker_image_name to $docker_image_name\n";

### Running AlphaFold2 docker image
my $prefix;
while (my $fasta = shift @fasta){

	my $basename = fileparse($fasta);
	($prefix) = $basename =~ /^(.*)\.\w+$/;

	## Checking if protein structures are already present in 3DFI output dir
	if (-f "$outdir/$prefix/ranked_0.pdb"){
		print "  AlphaFold predicted structure (ranked_0.pdb) found for $basename. Skipping folding...\n";
		next;
	}
	else {
		# Timestamp
		my $time = localtime;
		print "\n$time: working on $fasta\n";
		my $start = time;

		## Gpu check
		my $gpu_check = '';
		my $gpu_devices = "--gpu_devices=$gpus";

		if ($no_gpu){
			$gpu_check = '--use_gpu=False';
			$gpu_devices = '';
		}

		## MSA
		my $msa = 'False';
		if ($precomputed_msas){ $msa = 'True'; }

		# Folding
		system ("python3 \\
			$alpha_home/docker/run_docker.py \\
			--fasta_paths=$fasta \\
			--docker_image_name=$docker_image_name \\
			--data_dir=$alpha_db \\
			--output_dir=$outdir \\
			--max_template_date=$max_date \\
			--db_preset=$preset \\
			--use_precomputed_msas=$msa \\
			$gpu_devices \\
			$gpu_check
		") == 0 or checksig();

		my $run_time = time - $start;
		$run_time = $run_time/60;
		$run_time = sprintf ("%.2f", $run_time);
		print "\nTime to fold $basename: $run_time minutes\n";
		print LOG "Time to fold $basename: $run_time minutes\n";
	}
}

close LOG;

### Sub
sub checksig {

	my $exit_value = $?;
	my $modulo = $exit_value % 255;

	if ($modulo == 2) {
		print "\n\nSIGINT detected (Ctrl+c), exiting ...\n\n";
		exit(1);
	}
	elsif ($modulo == 131) {
		print "\n\nSIGTERM detected (Ctrl+\\), exiting ...\n\n";
		exit(1);
	}

}