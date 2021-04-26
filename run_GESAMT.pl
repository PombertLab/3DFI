#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.5b';
my $name = 'run_GESAMT.pl';
my $updated = '2021-04-25';

use strict; use warnings; use File::Find; use File::Basename;
use POSIX 'strftime'; use Getopt::Long qw(GetOptions);
my @command = @ARGV; ## Keeping track of command line for log

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Run GESAMT structural searches against PDB structures
REQUIREMENTS	PDB files downloaded from RCSB PDB; e.g. pdb2zvl.ent.gz
		GESAMT; see https://www.ccp4.ac.uk/

CREATE DB	${name} -cpu 10 -make -arch /media/Data_2/GESAMT_ARCHIVE -pdb /media/Data_2/PDB/
UPDATE DB	${name} -cpu 10 -update -arch /media/Data_2/GESAMT_ARCHIVE -pdb /media/Data_2/PDB/
QUERY DB	${name} -cpu 10 -query -arch /media/Data_2/GESAMT_ARCHIVE -input *.pdb -o ./ -mode normal 

OPTIONS:
-c (--cpu)	CPU threads [Default: 10]
-a (--arch)	GESAMT archive location [Default: ./]

## Creating/updating a GESAMT archive
-m (--make)	Create a GESAMT archive
-u (--update)	Update existing archive
-p (--pdb)	Folder containing RCSB PDB files to archive

## Querying a GESAMT archive
-q (--query)	Query a GESAMT archive
-i (--input)	PDF files to query
-o (--outdir)	Output directory [Default: ./]
-d (--mode)	Query mode: normal of high [Default: normal]

## References
1) Enhanced fold recognition using efficient short fragment clustering.
Krissinel E. J Mol Biochem. 2012;1(2):76-85. PMID: 27882309 PMCID: PMC5117261

2) Overview of the CCP4 suite and current developments
Winn MD et al. Acta Crystallogr D Biol Crystallogr. 2011 Apr;67(Pt 4):235-42. PMID: 21460441 PMCID: PMC3069738 DOI: 10.1107/S0907444910045749
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $cpu = 10;
my $arch = './';
my $make;
my $update;
my $pdb;
my $query;
my @input;
my $outdir = './';
my $mode = 'normal';
GetOptions(
	'c|cpu=i' => \$cpu,
	'a|arch=s' => \$arch,
	'm|make' => \$make,
	'u|update' => \$update,
	'p|pdb=s' => \$pdb,
	'q|query' => \$query,
	'i|input=s@{1,}' => \@input,
	'o|outdir=s' => \$outdir,
	'd|mode=s' => \$mode
);

## Creating log
my $date = strftime '%Y-%m-%d', localtime;
my $start = localtime();
my $tstart = time;
open LOG, ">>", "GESAMT_$date.log" or die "Can't create log file GESAMT_$date.log: $!\n";
print LOG "\nVERSION: $version\n"."COMMAND LINE: $name @command\n";
print LOG "Started on: $start\n";

## Program check
my $prog = `command -v gesamt`;
chomp $prog;
if ($prog eq ''){ 
	die "\nERROR: Cannot find gesamt. Please install GESAMT in your path\n\n";
}

## Checking for unknown task
if (!defined $update and !defined $make and !defined $query){
	die "\nUnknown task. Please specify -make, -update or -query on the command line.\n\n";
}

## Creating/updating GESAMT archive
unless (-d $arch){ 
	mkdir ($arch, 0755) or die "Can't create folder $arch: $!\n";
}

if ($update){
	system "gesamt \\
	  --update-archive $arch \\
	  -pdb $pdb \\
	  -nthreads=$cpu";
}
elsif ($make){
	system "gesamt \\
	  --make-archive $arch \\
	  -pdb $pdb \\
	  -nthreads=$cpu";
}

## Running GESAMT queries/Skipping previously done searches
unless (-d $outdir){ 
	mkdir ($outdir, 0755) or die "Can't create folder $outdir: $!\n";
}

my @gsm;
my %results;
find (sub {push @gsm, $File::Find::name unless -d}, $outdir);

while (my $gsm = shift(@gsm)){
	my ($result, $folder) = fileparse($gsm);
	$result =~ s/\.\w+\.gesamt$//;
	$results{$result} = 'done';
}

if ($query){
	while (my $file = shift(@input)){
		my ($pdb, $dir) = fileparse($file);
		$pdb =~ s/.pdb$//;
		unless (exists $results{$pdb}){
			system "gesamt $file \\
			  -archive $arch \\
			  -nthreads=$cpu \\
			  -$mode \\
			  -o $outdir/$pdb.$mode.gesamt";
		}
		## Searches can take a while, best to skip if done previously
		else { 
			print "Skipping PDB file: $pdb => GESAMT result found in output directory $outdir\n";
		}
	}
}

my $end = localtime();
my $endtime = time - $tstart;
print LOG "Completed on: $end\n";
print LOG "Total run time: $endtime sec\n";
close LOG;