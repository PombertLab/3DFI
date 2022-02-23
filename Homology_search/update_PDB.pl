#!/usr/bin/perl
## Pombert Lab 2021
my $version = '0.3';
my $name = 'update_PDB.pl';
my $updated = '2022-02-23';

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
		  -d current \\
		  -n 15

OPTIONS:
-o (--outdir)	PDB output directory [Default: PDB]
-n (--nice)	Defines niceness (adjusts scheduling priority)
-v (--verbose)	Adds verbosity
-d (--data)		Data to download; current or obsolete [Default: current]
		## current => /pub/pdb/data/structures/divided
		## obsolete => /pub/pdb/data/structures/obsolete
		## see https://www.rcsb.org/docs/programmatic-access/file-download-services
OPTIONS
die "\n$USAGE\n" unless @ARGV;

my $outdir = 'PDB';
my $data = 'current';
my $nice;
my $verbose;
GetOptions(
	'o|outdir=s' => \$outdir,
	'n|nice=i' => \$nice,
	'd|data=s' => \$data,
	'v|verbose' => \$verbose
);

## Checking output directory
unless (-d $outdir){
	mkdir($outdir, 0755) or die "Cannot create $outdir: $!\n";
}

## Checking data type
$data = lc($data);
if ($data eq 'current'){ $data = 'divided'; }
elsif ($data eq 'obsolete'){ $data = 'obsolete'; }
else {
	print "Unrecognized data type. Please use current or obsolete.\n";
	print "Exiting...\n";
	exit;
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
  rsync.rcsb.org::ftp_data/structures/$data/pdb/ \\
  $outdir";

