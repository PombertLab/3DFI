#!/usr/bin/perl
## Pombert Lab 2019
my $version = '0.6a';
my $name = 'raptorx.pl';
my $updated = '2021-07-23';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;
use Cwd; use Cwd 'abs_path';
my @command = @ARGV; ## Keeping track of command line for log

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs RaptorX template-based protein 3D structure prediction on provided fasta file(s)
REQUIREMENTS	RaptorX - http://raptorx.uchicago.edu/
		MODELLER - https://salilab.org/modeller/

USAGE		${name} \\
		  -t 10 \\
		  -k 2 \\
		  -i ~/FASTA/ \\
		  -o ~/3D_predictions/

OPTIONS:
-t (--threads)	Number of threads to use [Default: 10]
-i (--input)	Folder containing fasta files
-o (--output)	Output folder
-k (--TopK)	Number of top template(s) to use per protein for model building [Default: 1]
-m (--modeller)	MODELLER binary name [Default: mod10.1]
		## Use absolute or relative path if not set in \$PATH
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $threads = 10;
my $dir;
my $out;
my $modeller = 'mod10.1';
my $topk = 1;
GetOptions(
	't|threads=i' => \$threads,
	'i|input=s' => \$dir,
	'o|output=s' => \$out,
	'k|topk=i' => \$topk,
	'm|modeller=s' => \$modeller
);

## Checking for the presence of MODELLER
my $check_modeller = `which $modeller`;
chomp $check_modeller;
unless ($check_modeller =~ /$modeller/){
	print "\n\nCannot find MODELLER version: $modeller in the PATH. Please check if MODELLER is installed.\n\n";
	exit;
}

## Reading FASTA files from input folder
opendir (DIR, $dir) or die "Can't open FASTA input directory $dir: $!\n";
my @fasta;
while (my $fasta = readdir(DIR)){
	if ($fasta =~ /\w+/){ 
		my $abs_path_dir = abs_path($dir);
		push (@fasta, "$abs_path_dir/$fasta");
	}
}
@fasta = sort @fasta;
closedir DIR;

## Creating output folders
unless (-d $out){ mkdir ($out,0755) or die "Can't create output folder $out: $!\n"; }
unless (-d "$out/TGT"){ mkdir ("$out/TGT",0755) or die "Can't create output folder $out/TGT: $!\n"; }
unless (-d "$out/RANK"){ mkdir ("$out/RANK",0755) or die "Can't create output folder $out/RANK: $!\n"; }
unless (-d "$out/PDB"){ mkdir ("$out/PDB",0755) or die "Can't create output folder $out/PDB: $!\n"; }
unless (-d "$out/CNFPRED"){ mkdir ("$out/CNFPRED",0755) or die "Can't create output folder $out/CNFPRED: $!\n"; }
unless (-d "$out/FASTA_ALN"){ mkdir ("$out/FASTA_ALN",0755) or die "Can't create output folder $out/FASTA_ALN: $!\n"; }

## Creating LOG file
my $start = localtime(); my $tstart = time;
open LOG, ">", "$out/raptorx.log";
print LOG "COMMAND LINE:\nraptorx.pl @command\n"."raptorx.pl version = $version\n";
print LOG "Using MODELLER binary version $modeller\n";
print LOG "3D Folding started on: $start\n";

## Checking for RaptorX path variable (RAPTORX_PATH)
my $RAPTORX_PATH = '$RAPTORX_PATH';
my $prev_dir = cwd();
chomp ($RAPTORX_PATH = `echo $RAPTORX_PATH`);
chdir $RAPTORX_PATH or die "Can't access RAPTORX_PATH $RAPTORX_PATH: $!\n";

## Running RaptorX
while (my $fasta_path = shift@fasta){
	my $fasta = fileparse($fasta_path);
	my $pstart = time;
	my ($protein, $ext) = $fasta =~ /^(\S+?).(\w+)$/;

	## Skipping folding if pdb file(s) are present
	if ($topk == 1){
		if (-e "$prev_dir/$out/PDB/$protein.pdb"){
			print LOG "PDB has already been created for $fasta, moving to next file\n";
			print "PDB has already been created for $fasta, moving to next file\n";
			next;
		}
	}
	else {
		if (-e "$prev_dir/$out/PDB/$protein-m$topk.pdb"){
			print LOG "PDB files have already been created for $fasta, moving to next file\n";
			print "PDB files have already been created for $fasta, moving to next file\n";
			next;
		}
	}

	## Generating the feature file (.tgt)
	my $time = localtime;
	print "\n$time: Generating the feature file (.tgt) for $fasta with buildFeature\n\n";
	system "buildFeature \\
	  -i $fasta_path \\
	  -o $prev_dir/$out/TGT/$protein.tgt \\
	  -c $threads";

	unless (-e "tmp/$protein.acc"){
		print "$fasta failed to predict, moving to next protein\n";
		next;
	}

	##  Searching databases for top hits
	$time = localtime;
	print "\n$time: Generating list of top hits (.rank) for $fasta with CNFsearch\n\n";
	system "CNFsearch \\
	  -a $threads \\
	  -q $protein \\
	  -g $prev_dir/$out/TGT \\
	  -o $prev_dir/$out/RANK/$protein.rank";

	## Populating list of top models from .rank file
	open IN, "<", "$prev_dir/$out/RANK/$protein.rank";
	my @models;
	while (my $line = <IN>){
		chomp $line;
		if ($line =~ />(\w+)$/){
			push (@models, $1);
		}
	}

	## Aligning fasta to top k models
	$time = localtime;
	print "\n$time: Aligning $fasta to top model(s) with CNFalign_lite\n\n";
	for (0..$topk-1){
		system "CNFalign_lite \\
		  -t $models[$_] \\
		  -q $protein \\
		  -g $prev_dir/$out/TGT \\
		  -d $prev_dir/$out";
	}
	
	## Creating 3D models for the top k ranks
	$time = localtime;
	print "\n$time: Building PDB file(s) for $fasta from top model(s) with buildTopModels\n\n";
	system "buildTopModels \\
		-i $prev_dir/$out/RANK/$protein.rank \\
		-k $topk \\
		-m $modeller";

	## Writing timestamp to log file
	my $run_time = time - $tstart; ## Cumulative time elapsed
	my $pfold_time = time - $pstart; ## Time elapsed per protein
	print LOG "Time to fold $fasta = $pfold_time seconds\n";
	print LOG "Time to fold $fasta = $run_time seconds".' (cumulative)'."\n";

	## Moving datafiles to output directory
	opendir (RXDIR,"$RAPTORX_PATH");
	while (my $file = readdir(RXDIR)){
		if ($file =~ /\.pdb$/){
			if ($topk == 1){ system "mv $file $prev_dir/$out/PDB/$protein.pdb"; }
			else { ## if $topk > 1; keep model number to prevent overwriting file names
				my ($m_number) = $file =~ /\-(m\d+)\-(\w+)\.pdb$/;
				system "mv $file $prev_dir/$out/PDB/$protein-$m_number.pdb";
			}
		}
	}
	close RXDIR;
	system "rm -r tmp";

	opendir (OUTDIR,"$prev_dir/$out");
	while (my $file = readdir(OUTDIR)){
		## Reordering template name after the protein name for data structure sanity
		my ($template) = $file =~ /^(\w+)/; 
		if ($file =~ /cnfpred$/){ system "mv $prev_dir/$out/$file $prev_dir/$out/CNFPRED/$protein-$template.cnfpred"; }
		elsif ($file =~ /fasta$/){ system "mv $prev_dir/$out/$file $prev_dir/$out/FASTA_ALN/$protein-$template.fasta"; }
	}
	close OUTDIR;
}
my $mend = localtime();
print LOG "3D Folding ended on $mend\n\n";

## Printing a short description of folders and their contents
print LOG "OUTPUT directory = $out\n";
print LOG "PDB/: Contains the protein structure(s) (.pdb) predicted for each FASTA files\n";
print LOG "TGT/: Contains the feature files (.tgt) generated for each FASTA files\n";
print LOG "RANK/: Contains the lists (.rank) of the best templates/models found for each FASTA files\n";
print LOG "FASTA_ALN/: Contains pairwise alignments between FASTA sequences and their best template(s)/model(s) found in FASTA format\n";
print LOG "CNFPRED/: Contains pairwise alignments between FASTA sequences and their best template(s)/model(s) found in CNFPRED format\n";
