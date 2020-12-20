#!/usr/bin/perl
## Pombert Lab 2020
my $version = 0.2;
my $name = 'PDB_headers.pl';

use strict; use warnings;
use File::Find; use File::Basename;
use PerlIO::gzip; use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Generates a Tab-delimited list of PDB structures and their titles from the PDB files headers
REQUIREMENTS	PDB files downloaded from RCSB PDB; e.g. pdb2zvl.ent.gz
		PerlIO::gzip
		
USAGE EXAMPLE	PDB_headers.pl -p PDB/ -o PDB_titles.tsv

OPTIONS:
-p (--pdb)	Directory containing PDB files downloaded from RCSB PDB/PDBe (gzipped)
-o (--output)	Output file in tsv format
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $pdb;
my $out;
GetOptions(
	'p|pdb=s' => \$pdb,
	'o|output=s' => \$out,
);


## Recursing through PDB directory
my @pdb;
my $dir = "$pdb";  # PDB top directory
find( 
	sub { push @pdb, $File::Find::name unless -d; }, 
	$dir
);

## Parsing PDB files (*.ent.gz)
open OUT, ">$out";
while (my $pb = shift@pdb){
	if ($pb =~ /.ent.gz$/){ ## skipping other files if present
		open PDB, "<:gzip", "$pb" or die "Could not open $pb for reading: $!\n";
		my ($pdb, $folder) = fileparse($pb);
		$pdb =~ s/^pdb//;
		$pdb =~ s/.ent.gz$//;
		my $title = undef;
		print "Working on PDB file: $pb\n"; ## Added verbosity; lots of files to parse...
		while (my $line = <PDB>){
			chomp $line;
			if ($line =~ /^TITLE\s{5}(.*)$/){
				my $key = $1;
				$key =~ s/\s+$/ /; ## Discard trailing space characters
				$title .= $key;
			}
			elsif ($line =~ /^TITLE\s+\d+\s(.*)$/){
				my $key = $1;
				$key =~ s/\s+$/ /; ## Discard trailing space characters
				$title .= $key;
			}
		}
		binmode PDB, ":gzip(none)";
		print OUT "$pdb\t$title\n";
	}
}	
