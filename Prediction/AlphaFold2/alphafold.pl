#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'alphafold.pl';
my $version = '0.3a';
my $updated = '2021-07-20';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename; use POSIX qw(strftime);

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
-c (--casp14)		casp14 preset (--preset=casp14)
-d (--full_dbs)		full_dbs preset (--preset=full_dbs)
-n (--no_gpu)		Turns off GPU acceleration
-ah (--alpha_home)	AlphaFold2 installation directory
-ao (--alpha_out)	AlphaFold2 output directory

NOTE:	The -ia and -ao options are not required if the environment variables \$ALPHA_HOME and \$ALPHA_OUT are set, e.g.:
	export ALPHA_HOME=/opt/alphafold
OPTIONS
die "\n$usage\n" unless @ARGV;
my @command = @ARGV;

my @fasta;
my $outdir;
my $max_date = strftime("%F", localtime);
my $casp14;
my $fulldbs;
my $no_gpu;
my $alpha_home;
my $alpha_out;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|outdir=s' => \$outdir,
	'm|max_date=s' => \$max_date,
	'c|casp14' => \$casp14,
	'd|full_dbs' => \$fulldbs,
	'n|no_gpu' => \$no_gpu,
	'ah|alpha_home=s' => \$alpha_home,
	'ao|alpha_out=s' => \$alpha_out,
);

### Checking for AlphaFold2 installation; environment variables in Perl are loaded in %ENV
# Checking installation folder
if (!defined $alpha_home){
	if (exists $ENV{'ALPHA_HOME'}){ $alpha_home = $ENV{'ALPHA_HOME'}; }
	else {
		print "WARNING: The AlphaFold2 installation directory is not set as an environment variable (\$ALPHA_home) and the -ah option was not entered.\n";
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
	if (exists $ENV{'ALPHA_OUT'}){ $alpha_out = $ENV{'ALPHA_OUT'}; }
	else {
		print "WARNING: The AlphaFold2 output directory is not set as an environment variable (\$ALPHA_OUT) and the -ao option was not entered.\n";
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

### Checking output directory + creating log file
unless (-d $outdir){ mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n"; }
open LOG, ">>", "$outdir/alphafold2.log" or die "Can't create $outdir/alphafold2.log: $!\n";

my $timestamp = localtime;
print LOG "\nCOMMAND = $name @command\n";
print LOG "\nFolding started on $timestamp\n";
print LOG "\nSetting AlphaFold2 --max_template_date option to: $max_date\n\n";
print "\nSetting AlphaFold2 --max_template_date option to: $max_date\n";

### Checking if CASP14 is requested
my $preset = '';
if ($casp14){ $preset = '--preset=casp14'; }
elsif ($fulldbs) { $preset = '--preset=full_dbs'; }

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

		my $gpu_check = '';
		if ($no_gpu){ $gpu_check = '--use_gpu=False'; }

		# Folding
		system "python3 \\
			$alpha_home/docker/run_docker.py \\
			--fasta_paths=$fasta \\
			--max_template_date=$max_date \\
			$gpu_check \\
			$preset";

		# Checking permissions:
		# if docker image is ran with --privileged=True files will be owned by the root
		# if so, use cp instead of mv
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