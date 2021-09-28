#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'run_3DFI.pl';
my $version = '0.4.1';
my $updated = '2021-09-27';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Cwd qw(abs_path);
use POSIX 'strftime';

my $usage = <<"USAGE";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Master script to run the 3DFI pipeline

EXAMPLE		${name} \\
		  -f *.fasta \\
		  -o Results_3DFI \\
		  -p alphafold raptorx \\
		  -c 16 \\
		  -d /media/Data_3/databases/3DFI

GENERAL OPTIONS:
-h (--help)		Print detailed options
-f (--fasta)		Proteins to query (in FASTA format)
-o (--out)		Output directory [Default: Results_3DFI]
-p (--pred)		Structure predictor(s): alphafold, rosettafold, and/or raptorx
-c (--cpu)		# of CPUs to use [Default: 10]
-3do (--3D_only)	3D folding only; no structural homology search(es) / structural alignment(s)
-v (--viz)		Turn on visualization once the structural homology searches are completed
USAGE
die "\n$usage\n" unless @ARGV;

my $options = <<"OPTIONS";
ADVANCED OPTIONS:
## FASTA preparation
--window		Split individual fasta sequences into fragments using sliding windows [Default: off]
--win_size		Size of the the sliding window [Default: 250 (aa)]
--win_overlap		Sliding window overlap [Default: 100 (aa)]

## 3D Folding options
-n (--nogpu)		ALPHAFOLD/ROSETTAFOLD: Turn off GPU acceleration / use CPU only
-g (--gpu_dev)		ALPHAFOLD: list of GPU devices to use: e.g. all; 0,1; 0,1,2,3 [Default: all]
-m (--maxdate)		ALPHAFOLD: --max_template_date option (YYYY-MM-DD) [Default: current date]
--preset		ALPHAFOLD:  full_dbs, reduced_dbs or casp14 [Default: full_dbs]
-k (--ranks)		RAPTORX: # Number of top ranks to model [Default: 5]
--modeller		RAPTORX: Modeller version [Default: mod10.1]

## Structural homology / alignment
-d (--db)		3DFI database location containing the RCSB PDB files / GESAMT archive [Default: \$TDFI_DB]
-q (--qscore)		Mininum Q-score to keep [Default: 0.3]
-b (--best)		Keep the best match(es) only (top X hits) [Default: 5]
--query			Models to query per protein and predictor: all or best [Default: all]
OPTIONS

#####  Defining options
## General
my $help;
my @fasta;
my $outdir = 'Results_3DFI';
my @predictors;
my $cpu = 10;
my $tdo;

## Advanced
# FASTA
my $window;
my $win_size = 250;
my $win_overlap = 100;

# 3D folding
my $nogpu;
my $gpus = 'all';
my $maxdate;
my $preset = 'full_dbs';
my $ranks = 5;
my $modeller = 'mod10.1';

# Structural homology / alignment
my $database;
my $qscore = 0.3;
my $best = 5;
my $query = 'all';

# Visualization
my $visualization;

GetOptions(
	## General
	'h|help' => \$help,
	'f|fasta=s@{1,}' => \@fasta,
	'o|out=s' => \$outdir,
	'p|pred=s@{1,}' => \@predictors,
	'c|cpu=i' => \$cpu,
	'3do|3D_only)' => \$tdo,
	
	## Advanced
	# FASTA
	'window' => \$window,
	'win_size=i' => \$win_size,
	'win_overlap' => \$win_overlap,

	# 3D folding
	'n|nogpu' => \$nogpu,
	'g|gpu_dev=s' => $gpus,
	'k|ranks=i' => \$ranks,
	'm|maxdate=s' => \$maxdate,
	'modeller=s' => \$modeller,
	
	# Structural homology 
	'd|db=s' => \$database,
	'q|qscore=s' => \$qscore,
	'b|best=i' => \$best,
	'query=s' => \$query,

	# Visualization
	'v|viz' =>\ $visualization
);

if ($help){ die "\n$usage"."\n"."$options\n"; }

########################################################################################
##### Running pre-computation checks
my $time = localtime;

##### Check if environment variables are set

#### Checking for the $TDFI_HOME environment variable
my $home_3DFI;
if (exists $ENV{'TDFI_HOME'}){ $home_3DFI = $ENV{'TDFI_HOME'}; }
else {
	# If not set, capture it from the running script $0
	my $current_path = abs_path($0);
	($name,$home_3DFI) = fileparse($current_path);
	$home_3DFI =~ s/\/$//;
}

### TDFI_DB environment variable and database setup (if desired)
unless ($tdo){
	if (exists $ENV{'TDFI_DB'}){ $database = $ENV{'TDFI_DB'}; }
	else {
		unless ($database){
			print "No environment variable \$TDFI_DB was found and the -d (--db) option was not entered.\n";
			print "Exiting now...\n";
			exit;
		}
	}

	### Check if GESAMT archive exists in $DB_3DFI or --db location
	unless (-f "$database/RCSB_GESAMT/gesamt.archive.seq.000.pack"){ 
		print "\nNo GESAMT archive found in $database\n\n";
		print "Downloading the RCSB PDB data files ([36Gb] as of 2021-09-01) will take time.\n";
		print "Creating a GESAMT archive from these files (~180k entries) will also take a few hours.\n\n";
		print "Do you want to perform this task now? (y/n)\n";
		my $answer;
		ANSWER: {
			$answer = <STDIN>;
			chomp $answer;
			$answer = lc ($answer);
			if (($answer eq 'y') or ($answer eq 'yes')){
				print "\nDownloading data from RCSB PDB and creating a GESAMT archive. This will take time...\n";
				sleep(2);
				system "create_3DFI_db.pl \\
					-c $cpu \\
					-o $database";
			}
			elsif (($answer eq 'n') or ($answer eq 'no')){
				print "\nExiting as requested...\n\n";
				exit;
			}
			else {
				print "\nUnrecognized answer: $answer. Please try again...\n\n";
				goto ANSWER;
			}
		}
	}
}

### Protein stucture predictors environment variables
my %predictor_homes = (
	'raptorx' => 'RAPTORX_HOME',
	'alphafold' => 'ALPHAFOLD_HOME',
	'rosettafold' => 'ROSETTAFOLD_HOME'
);

# Checking only for HOME vars of requested predictors 
foreach my $pred (@predictors){
	$pred = lc($pred);
	if (!exists $predictor_homes{$pred}){
		print "\n[E] 3D structure predictor $pred not recognized. Exiting...\n\n";
		exit;
	}
	else {
		unless (exists $ENV{"$predictor_homes{$pred}"}){ 
			print "\n[E] Environment variable \$$predictor_homes{$pred} cannot be found. Exiting...\n\n";
			exit;
		}
	}
}

### Check if software prerequisites are found
foreach my $pred (@predictors){
	$pred = lc($pred);

	if ($pred eq 'raptorx'){
		my $check_modeller = `command -v $modeller`;
		chomp $check_modeller;
		unless ($check_modeller =~ /$modeller/){
			print "\n[E] Cannot find MODELLER version: $modeller in your \$PATH. Please check if MODELLER is installed.\n\n";
			exit;
		}
	}

}

unless ($tdo){
	my $gesamt_check = `command -v gesamt`;
	chomp $gesamt_check;
	if ($gesamt_check eq ''){ 
		print "\n[E]: Cannot find gesamt. Please install GESAMT in your \$PATH. Exiting..\n\n";
		exit;
	}

	my $chimerax_check = `command -v chimerax`;
	chomp $chimerax_check;
	if ($chimerax_check eq ''){ 
		print "\n[E]: Cannot find chimerax. Please install ChimeraX in your \$PATH. Exiting..\n\n";
		exit;
	}
}

### Check if output directory / subdirs can be created
my $fd_dir = "$outdir/Folding";
my $hm_dir = "$outdir/Homology";
my $vz_dir = "$outdir/Visualization";

unless (-d $outdir) { mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n"; }
unless (-d $fd_dir) { mkdir ($fd_dir, 0755) or die "Can't create $fd_dir: $!\n"; }

# Do not create homology/visualisation subdirs if --3D_only flag is on
unless ($tdo){ 
	unless (-d $hm_dir) { mkdir ($hm_dir, 0755) or die "Can't create $hm_dir: $!\n"; }
	unless (-d $vz_dir) { mkdir ($vz_dir, 0755) or die "Can't create $vz_dir: $!\n"; }
}

##### End of pre-computation checks



########################################################################################
##### Preparing FASTA files

$time = localtime;
print "\n".'##########################################################################';
print "\n# $time: Preparing FASTA files\n";

my $fasta_dir = "$outdir/FASTA";
unless (-d $fasta_dir) { mkdir ($fasta_dir, 0755) or die "Can't create $fasta_dir: $!\n"; }

## Making sure that the FASTA files are not multifasta files

my $tools = "$home_3DFI".'/Misc_tools';

unless ($window){
	system "$tools/split_Fasta.pl \\
		-f @fasta \\
		-o $fasta_dir \\
		-e fasta \\
		-v";
}
else {
	system "$tools/split_Fasta.pl \\
		-f @fasta \\
		-o $fasta_dir \\
		-e fasta \\
		--window \\
		--size $win_size \\
		--overlap $win_overlap \\
		-v";
}

$time = localtime;
print "\n# $time: FASTA files prepared\n";

##### End of FASTA prep



########################################################################################
##### Folding proteins with structure predictors

## Using all four predictors is not recommended for large numbers of proteins
## Computation time would be huge: ~ 2000 proteins with AlphaFold2 
## on an NVIDIA RTX A6000 takes about 40 days (~ 50 proteins per day)

my $pred_scripts_home;
## Using relative paths to set only one enviroment variable ($TDFI)
## and prevent possible clashes between similarly named scripts.

$time = localtime;
print "\n".'##########################################################################';
print "\n# $time: Folding proteins with structure predictors\n";

foreach my $predictor (@predictors){

	$predictor = uc($predictor);

	## RaptorX
	if ($predictor eq 'RAPTORX'){
		my $rx_dir = "$fd_dir/RAPTORX_3D/";
		unless (-d $rx_dir) { mkdir ($rx_dir, 0755) or die "Can't create $rx_dir: $!\n"; }
		
		$pred_scripts_home = "$home_3DFI".'/Prediction/RaptorX/';

		$time = localtime;
		print "\n# $time: Running RaptorX protein structure prediction\n";
		system "$pred_scripts_home"."raptorx.pl \\
			-t $cpu \\
			-k $ranks \\
			-i $fasta_dir \\
			-o $rx_dir";
	}

	## RoseTTAfold
	elsif ($predictor eq 'ROSETTAFOLD'){
		my $rf_dir = "$fd_dir/ROSETTAFOLD_3D";
		unless (-d $rf_dir) { mkdir ($rf_dir, 0755) or die "Can't create $rf_dir: $!\n"; }

		$pred_scripts_home = "$home_3DFI".'/Prediction/RoseTTAFold/';

		### If no GPU, use PyRosetta; if GPU use end-to-end 
		my $method;
		if ($nogpu){ $method = 'py'; }
		else { $method = 'e2e'; }

		## Running RoseTTAfold
		$time = localtime;
		print "\n# $time: Running RoseTTAfold protein structure prediction\n";
		system "$pred_scripts_home"."rosettafold.pl \\
			-f $fasta_dir/*.fasta \\
			-t $method \\
			-o $rf_dir";

		## Parsing RoseTTAfold output folders
		$time = localtime;
		print "\n# $time: Parsing RoseTTAfold protein structure prediction results\n";
		system "$pred_scripts_home"."parse_rf_results.pl \\
			-r $rf_dir \\
			-o $fd_dir/ROSETTAFOLD_3D_Parsed \\
			-p $method \\
			-t 5 \\
			-v";
	}

	## AlphaFold
	elsif ($predictor eq 'ALPHAFOLD'){
		my $af_dir = "$fd_dir/ALPHAFOLD_3D";
		unless (-d $af_dir) { mkdir ($af_dir, 0755) or die "Can't create $af_dir: $!\n"; }

		$pred_scripts_home = "$home_3DFI".'/Prediction/AlphaFold2/';

		## Checking options
		my $gpu_devices = "--gpu_dev $gpus";
		if ($nogpu) { $gpu_devices = '--no_gpu'; }
		my $maxdate_flag = '';
		if ($maxdate) { $maxdate_flag = "--max_date $maxdate"; }

		## Running alphafold
		$time = localtime;
		print "\n# $time: Running AlphaFold protein structure prediction\n";
		system "$pred_scripts_home"."alphafold.pl \\
			--fasta $fasta_dir/*.fasta \\
			--preset $preset \\
			$gpu_devices \\
			$maxdate_flag \\
			-o $af_dir";
		
		## Parsing AlphaFold output folders
		$time = localtime;
		print "\n# $time: Parsing AlphaFold protein structure prediction results\n";
		system "$pred_scripts_home"."parse_af_results.pl \\
			-a $af_dir \\
			-o $fd_dir/ALPHAFOLD_3D_Parsed \\
			-p k \\
			-t 5 \\
			-s";
	}
	else {
		print "\n[W] 3D structure predictor $predictor not recognized. Skipping...\n";
	}
	sleep (5);
}
##### End of protein folding

if ($tdo){
	$time = localtime;
	print "\n# $time: Folding step completed. -3do (--3D_only) flag detected.\n";
	print "Skipping structural homology searches and alignments, as requested.\n\n";
	exit;
}

########################################################################################
##### Running structural homology searches

$time = localtime;
print "\n".'##########################################################################';
print "\n# $time: Running structural homology searches\n";

my $homology_scripts_home = "$home_3DFI".'/Homology_search/';

my $gt_dir = "$hm_dir/GESAMT";
unless (-d $gt_dir) { mkdir ($gt_dir, 0755) or die "Can't create $gt_dir: $!\n"; }

foreach my $predictor (@predictors){

	$predictor = uc($predictor);
	my $GSMT_outdir = "$gt_dir/$predictor";

	## Input folders containing predicted PDB files
	my $input_pdbdir = "$fd_dir/${predictor}_3D";

	if ($predictor eq 'ALPHAFOLD'){
		$input_pdbdir .= '_Parsed';
	}
	elsif  ($predictor eq 'RAPTORX'){
		$input_pdbdir .= '/PDB';
	}
	elsif  ($predictor eq 'ROSETTAFOLD'){
		$input_pdbdir .= '_Parsed';
	}

	## Running GESAMT
	my $date = strftime('%Y-%m-%d', localtime);
	my $gesamt_archive = "$database/RCSB_GESAMT";
	my $log_dir = "$hm_dir/LOGS";
	unless (-d $log_dir){ mkdir ($log_dir, 0755) or die "Can't create $log_dir: $!\n"; }

	$time = localtime;
	print "\n# $time: Running structural homology searches with GESAMT on $input_pdbdir\n";
	
	## Query all (default) or only the best model per predictor?
	my $pdb_to_query = '*.pdb';
	$query = lc($query);
	if ($query eq 'best'){ $pdb_to_query = '*-m1.pdb'; }

	system "$homology_scripts_home"."run_GESAMT.pl \\
		-cpu $cpu \\
		-query \\
		-arch $gesamt_archive \\
		-input $input_pdbdir/$pdb_to_query \\
		-o $GSMT_outdir \\
		-l $log_dir/GESAMT_${predictor}_${date}.log \\
		-mode normal \\
		-z";
	
	## Adding descriptive information to GESAMT matches
	$time = localtime;
	
	print "\n# $time: Getting match descriptions from $GSMT_outdir\n";
	system "$homology_scripts_home"."descriptive_GESAMT_matches.pl \\
		-r $database/RCSB_PDB_titles.tsv \\
		-m $GSMT_outdir/*.gesamt.gz \\
		-q $qscore \\
		-b $best \\
		-l $log_dir/GESAMT_${predictor}_${date}_descriptive_matches.err \\
		-o $gt_dir/${predictor}_GESAMT_per_model.matches \\
		-n";
	
	## Parse descriptive matches per protein and Q-score; single predictor
	print "\n# $time: Getting match descriptions per protein and Q-score; single predictor\n";
	system "$homology_scripts_home"."parse_all_models_by_Q.pl \\
		-m $gt_dir/${predictor}_GESAMT_per_model.matches \\
		-o $gt_dir/${predictor}_GESAMT_per_protein.matches \\
		-x 50";
}

## Parse again by Q-score accross all predictors
print "\n# $time: Getting match descriptions per protein and Q-score; all predictors\n";
system "$homology_scripts_home"."parse_all_models_by_Q.pl \\
		-m $gt_dir/*_GESAMT_per_model.matches \\
		-o $gt_dir/All_GESAMT_matches_per_protein.tsv \\
		-x 50";

##### End of structural homology searches



######################################################################
## Structural aligments between queries and best matches with ChimeraX

$time = localtime;
print "\n".'###############################################################################################';
print "\n# $time: Performing aligments between queries and best matches with ChimeraX\n";
sleep (2);

my $visualization_scripts_home = "$home_3DFI".'/Visualization/';

foreach my $predictor (@predictors){

print "\n# $time: Working on $predictor predictions\n";
	$predictor = uc($predictor);
	my $PDB_dir = "$outdir/Folding/${predictor}_3D";

	if ($predictor eq 'ALPHAFOLD'){
		$PDB_dir .= '_Parsed';
	}
	elsif  ($predictor eq 'RAPTORX'){
		$PDB_dir .= '/PDB';
	}
	elsif  ($predictor eq 'TRROSETTA'){
		$PDB_dir .= '';
	}
	elsif  ($predictor eq 'ROSETTAFOLD'){
		$PDB_dir .= '_Parsed';
	}

	system "$visualization_scripts_home"."prepare_visualizations.pl \\
		-g $gt_dir/${predictor}_GESAMT_per_model.matches \\
		-p $PDB_dir/ \\
		-r $database/RCSB_PDB \\
		-o $vz_dir/$predictor \\
		-l $vz_dir/predicted_structures.log";
}

##### End of ChimeraX structural alignments

######################################################################
## Visualization with ChimeraX
if ($visualization){
	print "\n".'##########################################################################';
	print "\n# $time: Launching visualization script\n";
	sleep (5);
	system "$home_3DFI".'/'."run_visualizations.pl -r $outdir";
}

## End of visualization

##### End of script
$time = localtime;
print "\n# $time: run_3DFI.pl tasks completed\n\n";