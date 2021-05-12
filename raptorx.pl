#!/usr/bin/perl
## Pombert Lab 2019
my $version = '0.4';
my $name = 'raptorx.pl';
my $updated = '2021-05-12';

use strict; use warnings; use Getopt::Long qw(GetOptions); use Cwd;
my @command = @ARGV; ## Keeping track of command line for log

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs raptorX 3D structure prediction on provided fasta files
REQUIREMENTS	RaptorX - http://raptorx.uchicago.edu/
		MODELLER - https://salilab.org/modeller/

USAGE	
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

## Creating output folders
unless (-d $out){mkdir ($out,0755) or die "Can't create output folder $out: $!\n";}
unless (-d "$out/TGT"){mkdir ("$out/TGT",0755) or die "Can't create output folder $out/TGT: $!\n";}
unless (-d "$out/RANK"){mkdir ("$out/RANK",0755) or die "Can't create output folder $out/RANK: $!\n";}
unless (-d "$out/PDB"){mkdir ("$out/PDB",0755) or die "Can't create output folder $out/PDB: $!\n";}
unless (-d "$out/CNFPRED"){mkdir ("$out/CNFPRED",0755) or die "Can't create output folder $out/CNFPRED: $!\n";}

## Reading from folder
opendir (DIR, $dir) or die "Can't open FASTA input directory $dir: $!\n";
my @fasta;
while (my $fasta = readdir(DIR)){
	if ($fasta =~ /\w+/){ 
		push(@fasta,$fasta);
	}
}
@fasta = sort@fasta;
closedir DIR;

my $start = localtime(); my $tstart = time;
open LOG, ">", "$out/raptorx.log";
print LOG "COMMAND LINE:\nraptorx.pl @command\n"."raptorx.pl version = $version\n";
print LOG "Using MODELLER binary version $modeller\n";
print LOG "3D Folding started on: $start\n";

my $RAPTORX_PATH = '$RAPTORX_PATH';
my $prev_dir = cwd();
chomp($RAPTORX_PATH = `echo $RAPTORX_PATH`);
chdir $RAPTORX_PATH or die "Can't access $RAPTORX_PATH: $!\n";

## Running RaptorX
while (my $fasta = shift@fasta){
	my $pstart = time;
	my ($protein, $ext) = $fasta =~ /^(\S+?).(\w+)$/;

	if(-e "$prev_dir/$out/PDB/$protein.pdb"){
		print LOG "PDB has already been created for $fasta, moving to next file\n";
		print "PDB has already been created for $fasta, moving to next file\n";
		next;
	}
	
	## Generating the feature file (.tgt)
	print "Generating the .tgt file for $fasta\n";
	system "buildFeature \\
	  -i $prev_dir/$dir/$fasta \\
	  -o $prev_dir/$out/TGT/$protein.tgt \\
	  -c $threads"
	;

	unless (-e "tmp/$protein.acc"){
		print "$fasta failed to predict, moving to next protein\n";
		next;
	}

	##  Searching databases for top hits
	print "Generating top hits list for $fasta\n";
	system "CNFsearch \\
	  -a $threads \\
	  -q $protein \\
	  -g $prev_dir/$out/TGT \\
	  -o $prev_dir/$out/RANK/$protein.rank";

	## Creating list of top models from rank file
	open IN, "<", "$prev_dir/$out/RANK/$protein.rank";
	my @models;
		while (my $line = <IN>){
			chomp $line;
			if ($line =~ />(\w+)$/){
				push (@models, $1);
			}
		}

	## Aligning fasta to top models
	for (0..$topk-1){
		system "CNFalign_lite \\
		  -t $models[$_] \\
		  -q $protein \\
		  -d $prev_dir/$out"
		;
	}
	
	## Creating 3D modelsq
	system "buildTopModels \\
		-i $prev_dir/$out/RANK/$protein.rank \\
		-k $topk \\
		-m $modeller"
	;	

	my $run_time = time - $tstart; ## Cumulative time elapsed
	my $pfold_time = time - $pstart; ## Time elapsed per protein
	opendir(DIR,"./");
	while (my $file = readdir(DIR)){
		if ($file =~ /\.pdb$/){
			print LOG "Time to fold $fasta = $pfold_time seconds\n";
			print LOG "Time to fold $fasta = $run_time seconds".' (cumulative)'."\n";
			system "mv $file $prev_dir/$out/PDB/$protein.pdb";
		}
		if ($file =~ /\.cnfpred/){
			system "mv $file $prev_dir/$out/CNFPRED/$protein.cnfpred";
		}
	}
	close DIR;
	system "rm -r tmp";
}
my $mend = localtime();
print LOG "3D Folding ended on $mend\n\n";

