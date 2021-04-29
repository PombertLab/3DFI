#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.3';
my $name = 'PDB_headers.pl';
my $updated = '2021-04-29';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;
use File::Find; use PerlIO::gzip; 

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Generates a Tab-delimited list of PDB structures, their titles and 
		chains from the PDB files headers
		
REQUIREMENTS	PDB files downloaded from RCSB PDB; e.g. pdb2zvl.ent.gz
		PerlIO::gzip
		
USAGE EXAMPLE	${name} \\
		  -p PDB/ \\
		  -o PDB_titles.tsv

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
open OUT, ">", "$out" or die "Can't create file $out: $!\n";
while (my $pb = shift@pdb){

	if ($pb =~ /.ent.gz$/){ ## skipping other files if present

		open PDB, "<:gzip", "$pb" or die "Can't open file $pb: $!\n";
		my ($pdb, $folder) = fileparse($pb);
		$pdb =~ s/^pdb//;
		$pdb =~ s/.ent.gz$//;
		my $title = undef;
		my %molecules;
		my $mol_id = undef;

		print "Working on PDB file: $pb\n"; ## Added verbosity; lots of files to parse...

		while (my $line = <PDB>){
			chomp $line;
			## Getting title info from TITLE entries
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
			## Getting chain information from COMPND entries
			elsif ($line =~ /^COMPND\s+(\d+)?\s?MOL_ID:\s(\d+)/){
				$mol_id = $2;
			}
			elsif ($line =~ /^COMPND\s+(\d+)?(.*)$/){
				my $data = $2;
				$data =~ s/\s+$//;
				$molecules{$mol_id} .= $data;
			}
		}
		binmode PDB, ":gzip(none)";

		## Printing title
		print OUT "$pdb\tTITLE\t$title\n";

		## Printing chain(s)
		foreach my $id (sort (keys %molecules)){

			my ($molecule) = $molecules{$id} =~ /MOLECULE: (.*?);/;
			my $chains;

			if ($molecules{$id} =~ /CHAIN: (.*?);/){
				$chains = $1;
			}
			elsif ($molecules{$id} =~ /CHAIN: (.*?)/){
				$chains = $1;
				## If at end of COMPND section, no semicolon to after the chain(s)
			}
			else {
				print STDERR "Check $pb for issue(s) with chain\n";
			}

			$chains =~ s/ //g;
			my @chains = split (",", $chains);
			foreach my $chain (@chains){
				print OUT "$pdb\t$chain\t$molecule\n";
			}
		}
	}
}
