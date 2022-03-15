#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.4';
my $name = 'split_PDB.pl';
my $updated = '2022-02-24';

use strict;
use warnings;
use PerlIO::gzip;
use File::Basename;
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Splits a PDB file into separate files, one per chain
		
USAGE EXAMPLE	${name} \\
		  -p files.pdb \\
		  -o output_folder \\
		  -e pdb

OPTIONS:
-p (--pdb)	PDB input file (supports gzipped files)
-o (--outdir)	Output directory [Default: ./]
-e (--ext)	Desired file extension [Default: pdb]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @pdb;
my $outdir = './';
my $ext = 'pdb';
GetOptions(
	'p|pdb=s@{1,}' => \@pdb,
	'o|outdir=s' => \$outdir,
	'e|ext=s'	=> \$ext
);

## Output dir
unless (-d $outdir) {
	make_path( $outdir, { mode => 0755 } )  or die "Can't create $outdir: $!\n";
}

## Working on PDB files
while (my $pdb = shift@pdb){

	my ($filename, $dir) = fileparse($pdb);
	my ($prefix) = $filename =~ /^(\w+)/;

	## Creating subdir per PDB file
	my $subdir = "$outdir/$prefix";
	mkdir ("$subdir",0755) or die "Can't create folder $subdir: $!\n";

	## Working on PDB file
	my $gzip = '';
	if ($pdb =~ /.gz$/){ $gzip = ':gzip'; }
	open PDB, "<$gzip", "$pdb" or die "Can't open PDB file $pdb: $!\n";
	
	my @header;
	my $chain;
	my %chains;
	my $type = '';
	
	while (my $line = <PDB>){

		chomp $line;

		if ($line =~ /^HEADER|TITLE|SOURCE|KEYWDS|EXPDTA|REVDAT|JRNL/){
			push (@header, $line);
		}
		## Check if chain is amino acids
		elsif ($line =~ /^ATOM.{13}\w{3}\s(\w)/){
			$type = 'aa';
			$chain = $1;
			push (@{$chains{$chain}}, $line);
		}
		## Check if chain is nucleotide or something else
		elsif ($line =~ /^ATOM/){
			$type = 'unknown';
			$chain = undef;
		}
		## Only push if chain is amino acids
		elsif ($line =~ /^TER/){
			if ($type eq 'aa'){
				if (defined $chain){
					push (@{$chains{$chain}}, $line);
				}
				else {
					print STDERR "File $pdb: $line\n";
				}
			}
		}

	}
	if ($gzip eq ':gzip'){ binmode PDB, ":gzip(none)"; }

	## Working on chains
	for my $ch (keys %chains){

		open OUT, ">", "$subdir/${prefix}_$ch.$ext" or die "Can't create PDB file $pdb in folder $subdir: $!\n";

		## write header
		foreach (@header){
			print OUT "$_\n";
		}
		my @core = @{$chains{$ch}};
		for (0..$#core){
			print OUT "$core[$_]\n";
		} 

		close OUT;
	}
}