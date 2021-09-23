#!/usr/bin/perl
## Pombert Lab 2021
my $version = '0.2';
my $name = 'update_PDB.pl';
my $updated = '2021-09-23';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Downloads/updates the RCSB PDB database with rsync

COMMAND 	${name} \\
		  -o ./PDB \\
		  -n 15

OPTIONS:
-o (--outdir)	PDB output directory [Default: PDB]
-n (--nice)	Defines niceness (adjusts scheduling priority)
-v (--verbose)	Adds verbosity
OPTIONS
die "\n$USAGE\n" unless @ARGV;

my $outdir = 'PDB';
my $nice;
my $verbose;
GetOptions(
	'o|outdir=s' => \$outdir,
	'n|nice=i' => \$nice,
	'v|verbose' => \$verbose
);

## Checking output directory
unless (-d $outdir){
	mkdir($outdir, 0755) or die "Cannot create $outdir: $!\n";
}

## Defining niceness / verbosity
my $prg = "";
if ($nice){ $prg = "nice -n $nice"; }

## Running task with adjusted niceness, if desired
print "Downloading RCSB PDB files with rsync:\n\n";
system "$prg \\
  rsync \\
  -rlpt \\
  --info=progress2 \\
  -z \\
  --delete \\
  --port=33444 \\
  rsync.rcsb.org::ftp_data/structures/divided/pdb/ \\
  $outdir";

