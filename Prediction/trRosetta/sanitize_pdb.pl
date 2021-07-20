#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.2a';
my $name = 'sanitize_pdb.pl';
my $updated = '2021-04-21';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Cleans .pdb files genrated with trRosetta to remove non-standard PDB entries

COMMAND		${name} \\
		-p PDB/*.pdb \\
		-o PDB_clean

OPTIONS:
-p (--pdb)	.pdb files generated by trRosetta
-o (--output)	Output folder [Default: ./]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @pdb;
my $out = './';
GetOptions(
	'p|pdb=s@{1,}' => \@pdb,
	'o|output=s' => \$out,
);

## Checking output directory
unless (-d $out){
	mkdir ($out,0755) or die "Can't create folder $out: $!\n";
}

## cleaning up pdb files
while (my $pdb = shift@pdb){

	open PDB, "<", "$pdb" or die "Can't read file $pdb: $!\n";
	my($name, $dir) = fileparse($pdb);
	open CLEAN, ">", "$out/$name" or die "Can't create file $out/$name: $!\n";

	my @tags = ('HEADER', 'EXPDTA', 'REMARK', 'ATOM', 'TER');
	while (my $line = <PDB>){
		chomp $line;
		foreach (@tags){
			if ($line =~ /^$_/){ print CLEAN "$line\n"; }
		}
	}
	close PDB;
	close CLEAN;
}