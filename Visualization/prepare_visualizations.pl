#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = "prepare_visualizations.pl";
my $version = "0.7";
my $updated = "2022-05-13";

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Cwd qw(abs_path);

my $usage = << "EXIT";
NAME	${name}
VERSION	${version}
UPDATED	${updated}

SYNOPSIS	Creates ChimeraX visual comparisons between predicted .pdb structures
		and matches found with experimental structures from RCSB PDB.

USAGE	${name} \\
		-a gesamt \\
		-m GESAMT.RCSB.matches \\
		-r /media/FatCat/Databases/RCSB/PDB /media/FatCat/Databases/RCSB/PDB_obsolete \\
		-p Pred_PDB \\
		-k 

OPTIONS
-a (--align)	3D alignment tool: foldseek or gesamt [Default: gesamt]
-m (--matches)	Foldseek/GESAMT matches parsed by descriptive_matches.pl
-p (--pred)	Absolute path to predicted .pdb files
-r (--rcsb)	Absolute path to RCSB .ent.gz files
-k (--keep)	Keep unzipped RCSB .ent files
-o (--outdir)	Output directory for ChimeraX sessions [Default: ./3D_Visualizations]
-l (--log)	Location for log of predicted structures
EXIT
die "\n\n$usage\n\n" unless @ARGV;

my $aligner = 'gesamt';
my $match_file;
my $pdb;
my @rcsb;
my $rcsb_list;
my $keep;
my $outdir = './3D_Visualizations';
my $log_file;

GetOptions(
	'a|align=s' => \$aligner,
	'm|match=s' => \$match_file,
	'p|pdb=s' => \$pdb,
	'r|rcsb=s@{1,}' => \@rcsb,
	'k|keep' => \$keep,
	'o|out=s' => \$outdir,
	'l|log=s' => \$log_file,
);


## Check that all mandatory args have been provided
Check_Mand_Args();

unless (-d $outdir){
	mkdir ($outdir,0755) or die "\n[ERROR]\tUnable to create $outdir: $!\n";
}

## Loading pre-existing data into memory to identify new results
my %stored_pred;
if (-e $log_file){
	open LOG, "<", "$log_file";
	while (my $line = <LOG>){
		chomp($line);
		$stored_pred{$line} = 1;
	}
	close LOG;
}

## Load predicted pdb filenames into database
if ($log_file){
	open LOG,">>","$log_file" or die "\n[WARNING]\tUnable to access $log_file: $!\n";
}
my %pred;
opendir (PRED,$pdb) or die "\n[ERROR]\tCan't open $pdb: $!\n";
while (my $file = readdir(PRED)){
	unless (-d $file){
		if ($file =~ /^(\S+)\.pdb/){
			my $model = $1;
			$pred{$model} = "$pdb/$file";
			## Make a directory for each locus that has a pdb file
			unless (-d "$outdir/$model"){
				mkdir ("$outdir/$model",0755) or die "Can't create $outdir/$model: $!\n";
			}
			## Copy the pdb file to the locus directory
			system "cp $pdb/$file $outdir/$model/$file";
			unless ($stored_pred{"$outdir/$model/$file"}){
				if ($log_file){
					print LOG "$outdir/$model/$file\n";
				}
			}
		}
	}
}
closedir PRED;

## Link RCSB PDB files to their file locations
my %db;
foreach my $rcsb (@rcsb){
	## Recurse through the RCSB PDB database
	opendir (EXT,$rcsb) or die "\n[ERROR]\tCan't open $rcsb: $!\n";
	while (my $dir = readdir(EXT)){
		## Ignoring files, if any
		if ($dir =~ /^\w+/){
			opendir (INT,"$rcsb/$dir") or die "Can't open $rcsb/$dir: $!\n";
			while (my $file = readdir(INT)){
				## Store the absolute file path under the filename of the .ent.gz file
				if ($file =~ /^\w+/){
					$db{$file} = "$rcsb/$dir/$file";
				}
			}
			closedir INT;
		}
	}
	closedir EXT;
}

## For each match, get the filename of the best match for RCSB
open MATCH, "<", "$match_file" or die "Can't open $match_file: $!\n";

my $model_tag;
my %sessions;

while (my $line = <MATCH>){
	chomp $line;
	## Check the PDB headers for proteins that are in the selection provided
	if ($line =~ /^###/){
		my $filename = (fileparse($line))[0];
		if ($aligner eq "gesamt"){
			($model_tag) = $filename =~ /### (\S+)\;/;
		}
		elsif ($aligner eq "foldseek"){
			($model_tag) = $filename =~ /### (\S+)/;
		}
		
	}
	## Store the matching RCSB .ent.gz filepath  under the locus tag
	else{
		my @data = split("\t",$line);
		my $pdb_file;
		my $pdb_chain;
		if ($aligner eq 'gesamt'){
			$pdb_chain = $data[3];
			$pdb_file = $data[9];
		}
		elsif ($aligner eq 'foldseek'){
			## Data columns for foldseek files are:
			# query, target, fident, alnlen, mismatch, gapopen, qstart, qend,
			# tstart, tend, evalue, bits
			if ($data[1] =~ /^(pdb\w{4}.ent.gz)_(\S+)$/){
				$pdb_file = $1;
				$pdb_chain = $2;
			}
		}
		if ($db{$pdb_file}){
			push (@{$sessions{$model_tag}}, "$db{$pdb_file};$pdb_chain");
		}
		else{
			print $model_tag." will not be aligned to ".$pdb_file." because ".$pdb_file." could not be found!\n";
		}
	}
}
close MATCH;

## For each session create a visualization of the predicted pdb, and if given, the alignment between the predicted
## pdb and the matching RCSB chain
my ($filename,$dir) = fileparse($0);
my $script = "$dir/Helper_Scripts/chimerax_session_creator.py";
foreach my $locus (sort(keys(%sessions))){
	my $pred_file = $pred{$locus};
	## If there are any matches with RCSB, create those visualizations 
	if (scalar(@{$sessions{$locus}}) >= 1){
		foreach my $match (@{$sessions{$locus}}){
			if ($match){
				my @data = split(";",$match);
				my $pdb_file = $data[0];
				my ($rcsb_name) = $pdb_file =~ /pdb(\w+).ent.gz$/;
				my $chain = $data[1];

				## Create temporary unzipped version of RCSB file for ChimeraX session creation
				my $temp = "$outdir/$locus/$rcsb_name.pdb";
				system "zcat $pdb_file > $temp";

				$outdir = abs_path($outdir);
				my $cxs_name = "$outdir/$locus/${locus}_${rcsb_name}_$chain.cxs";
				if (-e $cxs_name) { print "  Alignment between $locus and $rcsb_name chain $chain found. Skipping alignment...\n"; }
				else {
					# ChimeraX API calling
					print "  Aligning $locus to chain $chain from $rcsb_name with ChimeraX\n";
					system ("chimerax 1> /dev/null --nogui $script \\
						-p $pred_file \\
						-r $temp \\
						-m $rcsb_name \\
						-c $chain \\
						-o $outdir/$locus\n"
					;) == 0 or checksig();
				}
				## Remove temporary file unless explicitly told not to
				unless ($keep){
					system "rm $temp";
				}
			}
		}
	}
}

## Subroutines
sub Check_Mand_Args{
	die "\n[ERROR]\tGESAMT descriptive match file not provided\n\n$usage\n\n" unless $match_file;
	die "\n[WARNING]\tRCSB PDB directory(s) not provided, no visualizations will be made" unless @rcsb;
	die "\n[ERROR]\tPredicted PDB directory not provided\n\n$usage\n\n" unless $pdb;
}

### Subroutine(s)
sub checksig {

	my $exit_code = $?;
	my $modulo = $exit_code % 255;

	print "\nExit code = $exit_code; modulo = $modulo \n";

	if ($modulo == 2) {
		print "\nSIGINT detected: Ctrl+C => exiting...\n";
		exit(2);
	}
	elsif ($modulo == 131) {
		print "\nSIGTERM detected: Ctrl+\\ => exiting...\n";
		exit(131);
	}

}