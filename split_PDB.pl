#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.3a';
my $name = 'split_PDB.pl';

use strict; use warnings;
use PerlIO::gzip; use File::Basename;
use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Splits a PDB file into separate files, one per chain
		
USAGE EXAMPLE	$name -p files.pdb -o output_folder -e pdb

OPTIONS:
-p (--pdb)	PDB input file (supports gzipped files)
-o (--output)	Output directory. If blank, will create one folder per PDB file based on file prefix
-e (--ext)	Desired file extension [Default: pdb]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @pdb;
my $out;
my $ext = 'pdb';
GetOptions(
	'p|pdb=s@{1,}' => \@pdb,
	'o|output=s' => \$out,
	'e|ext=s'	=> \$ext
);

while (my $pdb = shift@pdb){
	my ($filename, $dir) = fileparse($pdb);
	my ($prefix) = $filename =~ /^(\w+)/;

	## Creating output folder
	if (!defined $out){unless (-e $prefix) {mkdir $prefix or die "Can't create folder: $prefix. Please check file permissions\n";}}
	else {unless (-e $out) {mkdir $out or die "Can't create folder: $out. Please check file permissions\n";}}

	## Working on PDB file
	my $gzip = ''; if ($pdb =~ /.gz$/){$gzip = ':gzip';}
	open PDB, "<$gzip", "$pdb" or die "Can't open PDB file: $pdb\n";
	my %chains; my $chain; my @header; my %ids; my $molecule; my $cpchain;
	while (my $line = <PDB>){
		chomp $line;
		if ($line =~ /^HEADER|TITLE|SOURCE|KEYWDS|EXPDTA|REVDAT|JRNL/){push(@header, $line);}
		elsif ($line =~ /^COMPND\s+\d+\s+(MOLECULE:\s.*)$/){$molecule = $1;}
		elsif ($line =~ /^COMPND\s+\d+\s+CHAIN:\s(.*);/){
			my @chains = split(",", $1);
			foreach (@chains){
				$_ =~ s/ //g;
				$cpchain = $_;
				$ids{$cpchain} = $molecule;
			}
		}
		elsif ($line =~ /^ATOM\s+\d+\s+\S+\s+\w{3}\s(\S)/){
			$chain = $1;
			push (@{$chains{$chain}}, $line);
		}
		elsif($line =~ /^TER\s+\d+\s+\w{3}\s(\S)/){
			$chain = $1;
			push (@{$chains{$chain}}, $line);
		}
	}
	if ($gzip eq ':gzip'){binmode PDB, ":gzip(none)";}

	## Working on chains
	for (keys %chains){
		my $ch = $_;
		if (defined $out){open OUT, ">", "$out/${prefix}_$ch.$ext" or die "Can't create PDB file: $pdb in folder $out\n";}
		else{open OUT, ">", "$prefix/${prefix}_$ch.$ext" or die "Can't create PDB file: $pdb in folder $out\n";}
		foreach (@header){print OUT "$_\n";}
		if (exists $ids{$ch}){
			print OUT "COMPND    MOL_ID: 1;                                                            \n";
			if ($ids{$ch} =~ /;/){print OUT "COMPND   2 $ids{$ch}\n";}
			else{
				chop $ids{$ch}; $ids{$ch} .= ';';
				print OUT "COMPND   2 $ids{$ch}\n";
			}
			print OUT "COMPND   3 CHAIN: $ch;                                                            \n";
		}
		else{print "Can't find DATA for $ch\n";}
		while (my $line = shift @{$chains{$ch}}){print OUT "$line\n";}
		close OUT;
	}
}