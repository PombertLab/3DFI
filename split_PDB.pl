#!/usr/bin/perl
## Pombert Lab 2020
my $version = 0.1;
my $name = 'split_PDB.pl';

use strict; use warnings;
use PerlIO::gzip; use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Splits a PDB file into separate files, one per chain
		
USAGE EXAMPLE	$name -p file.pdb -o output_folder -e pdb

OPTIONS:
-p (--pdb)	PDB input file (supports gzipped files)
-o (--output)	Output directory; defaults to file name prefix
-e (--ext)	Desired file extension [Default: pdb]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $pdb;
my $out;
my $ext = 'pdb';
GetOptions(
	'p|pdb=s' => \$pdb,
	'o|output=s' => \$out,
	'e|ext=s'	=> \$ext
);

## Creating output folder
if (!defined $out){
	if ($pdb =~ /.gz$/){($out) = $pdb =~ /^(.*?).\w+.gz$/;}
	else{($out) = $pdb =~ /^(.*?).\w+$/;}
}
if (-e $out){
	print "Folder $out already exists... Do you want to continue? (y or n)\n";
	my $answer = <STDIN>;
	chomp $answer; $answer = lc($answer);
	if ($answer eq 'n'){die "Stopping as requested\n";}
}
else {mkdir $out or die "Can't create folder: $out. Please check file permissions\n";}

## Working on PDB file
my $gzip = ''; if ($pdb =~ /.gz$/){$gzip = ':gzip';}
open PDB, "<$gzip", "$pdb" or die "Can't open PDB file: $pdb\n";
my %chains; my $chain; my @header; my %ids; my $molecule; my $cpchain;
while (my $line = <PDB>){
	chomp $line;
	if ($line =~ /^HEADER|TITLE/){push(@header, $line);}
	elsif ($line =~ /^COMPND\s+\d+\s+(MOLECULE:\s.*)$/){$molecule = $1;}
	elsif ($line =~ /^COMPND\s+\d+\s+CHAIN:\s(.*);/){
		my @chains = split(",", $1);
		foreach (@chains){
			$_ =~ s/ //g;
			$cpchain = $_;
			$ids{$cpchain} = $molecule;
		}
	}
	elsif ($line =~ /^ATOM\s+\d+\s+\S+\s+\w+\s+([^\d\s])+/){
		$chain = $1;
		push (@{$chains{$chain}}, $line);
	}
	elsif($line =~ /^TER\s+\d+\s+\w+\s+([^\d\s])+/){
		$chain = $1;
		push (@{$chains{$chain}}, $line);
	}
}
if ($gzip eq ':gzip'){binmode PDB, ":gzip(none)";}

## Working on chains
for (keys %chains){
	my $ch = $_;
	open OUT, ">", "$out/${out}_$ch.$ext" or die "Can't create PDB file: $pdb in folder $out\n";
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