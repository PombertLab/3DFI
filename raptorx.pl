#!/usr/bin/perl
## Pombert Lab 2019
my $version = '0.3a';
my $name = 'raptorx.pl';
my $updated = '12/03/2021';

use strict; use warnings; use Getopt::Long qw(GetOptions);
my @command = @ARGV; ## Keeping track of command line for log

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs raptorX 3D structure prediction on provided fasta files
REQUIREMENTS	RaptorX - http://raptorx.uchicago.edu/
		MODELLER - https://salilab.org/modeller/

NOTE		Due to RaptorX's architecture, 3D predictions must be launched from within RaptorX's installation directory.

USAGE EXAMPLE	cd RAPTORX_INSTALLATION_DIRECTORY/
		${name} \\
		  -t 10 \\
		  -k 2 \\
		  -i ~/FASTA/ \\
		  -o ~/3D_predictions/

OPTIONS:
-t (--threads)	Number of threads to use [Default: 10]
-i (--input)	Folder containing fasta files
-o (--output)	Output folder
-k (--TopK)	Number of top template(s) to use per protein for model building [Default: 1]
-m (--modeller)	MODELLER binary name [Default: mod9.23] ## Use absolute or relative path if not set in \$PATH
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $threads = 10;
my $dir;
my $out;
my $modeller = 'mod9.23';
my $topk = 1;
GetOptions(
	't|threads=i' => \$threads,
	'i|input=s' => \$dir,
	'o|output=s' => \$out,
	'k|topk=i' => \$topk,
	'm|modeller=s' => \$modeller
);

## Creating output folders
unless (-e $out){mkdir ($out,0755) or die "Can't create output folder $out: $!\n";}
unless (-e "$out/PDB"){mkdir ("$out/PDB",0755) or die "Can't create output folder $out/PDB: $!\n";}
unless (-e "$out/CNFPRED"){mkdir ("$out/CNFPRED",0755) or die "Can't create output folder $out/CNFPRED: $!\n";}
unless (-e "$out/RANK"){mkdir ("$out/RANK",0755) or die "Can't create output folder $out/RANK: $!\n";}

## Reading from folder
opendir (DIR, $dir) or die "Can't open input directory $dir: $!\n";
my @fasta;
while (my $fasta = readdir(DIR)){
	unless (-d){
		if (($fasta eq '.') || ($fasta eq '..')){next;}
		else{push (@fasta, $fasta);}
	}
}
@fasta = sort@fasta;

## Running RaptorX
my $start = localtime(); my $tstart = time;
open LOG, ">", "$out/raptorx.log";
print LOG "COMMAND LINE:\nraptorx.pl @command\n"."raptorx.pl version = $version\n";
print LOG "Using MODELLER binary version $modeller\n";
print LOG "3D Folding started on: $start\n";
while (my $fasta = shift@fasta){
	my $pstart = time;
	my ($protein, $ext) = $fasta =~ /^(\S+?).(\w+)$/;
	system "buildFeature -i ${dir}$protein.$ext -o TGT/$protein.tgt -c $threads";	## Generating the feature file (.tgt)
	system "CNFsearch -a $threads -q $protein -o $protein.rank";	##  Searching databases for top hits
	open IN, "<$protein.rank"; ## Creating list of top models from rank file
	my @models;
		while (my $line = <IN>){
			chomp $line;
			if ($line =~ />(\w+)$/){push (@models, $1);}
		}
	for (0..$topk-1){system "CNFalign_lite -t $models[$_] -q $protein -d .";}	## Aligning fasta to top models
		system "buildTopModels -i $protein.rank -k $topk -m $modeller";	## Creating 3D models
	my $run_time = time - $tstart; ## Cumulative time elapsed
	my $pfold_time = time - $pstart; ## Time elapsed per protein
	print LOG "Time to fold $protein.$ext = $pfold_time seconds\n";
	print LOG "Time to fold $protein.$ext = $run_time seconds".' (cumulative)'."\n";
	system "mv *.pdb $out/PDB/; mv *.cnfpred $out/CNFPRED/; mv *.rank $out/RANK/";
}
my $mend = localtime();
print LOG "3D Folding ended on $mend\n\n";

