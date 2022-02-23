#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.4b';
my $name = 'PDB_headers.pl';
my $updated = '2022-02-23';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use File::Find;
use PerlIO::gzip; 

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
		  -p RCSB_PDB/ RCSB_PDB_obsolete/\\
		  -o RCSB_PDB_titles.tsv \\
		  -v 1000

OPTIONS:
-p (--pdb)	Directories containing PDB files downloaded from RCSB PDB/PDBe (gzipped)
-o (--output)	Output file in tsv format
-f (--force)	Regenerate all PDB titles ## Default off
-v (--verbose)	Prints progress every X file [Default: 1000]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @pdbs;
my $rcsb_list;
my $force;
my $verbose = 1000;
GetOptions(
	'p|pdb=s@{1,}' => \@pdbs,
	'o|output=s' => \$rcsb_list,
	'f|force' => \$force,
	'v|verbose=i' => \$verbose
);


## Recursing through PDB directory
my @pdb;
for my $dir (@pdbs){
	find( 
		sub { push @pdb, $File::Find::name unless -d; }, 
		$dir
	);
}

## Doing a first pass to see which files have been parsed previously
## Should reduce overall computation time by skipping parsing
my %previous_data;
my $diamond = '>';
unless ($force){
	if (-f $rcsb_list){
		$diamond = '>>'; 
		open LIST, "<", "$rcsb_list" or die "Can't read $rcsb_list: $!\n";
		while (my $line = <LIST>){
			chomp $line;
			if ($line =~ /^(\w+)/){
				my $rcsb_entry = $1;
				$previous_data{$rcsb_entry} = 1;
			}
		}
		close LIST;
	}
}

## Parsing PDB files (*.ent.gz)
open OUT, "$diamond", "$rcsb_list" or die "Can't create file $rcsb_list: $!\n";

my $pdb_count = 0;
my $start = time;
while (my $pb = shift@pdb){

	if ($pb =~ /.ent.gz$/){ ## skipping other files if present

		$pdb_count++;

		## Grabbing RCSB PDB entry name from pdb file
		my ($pdb, $folder) = fileparse($pb);
		$pdb =~ s/^pdb//;
		$pdb =~ s/.ent.gz$//;

		## verbosity; lots of files to parse...
		my $modulo = ($pdb_count % $verbose);
		my $current_count = commify($pdb_count);
		if ($modulo == 0){ print "Working on PDB file # $current_count: $pb\n"; }

		## Working on PDB if is has not been seen before
		if (exists $previous_data{$pdb}) { next; }
		else {
			open PDB, "<:gzip", "$pb" or die "Can't open file $pb: $!\n";
			my $title = undef;
			my %molecules;
			my $mol_id = undef;

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

				my $molecule;
				my $chains;

				if ($molecules{$id} =~ /MOLECULE: (.*?);/){
					$molecule = $1;
				}
				elsif($molecules{$id} =~ /MOLECULE: (.*?)/){
					$molecule = $1;
					## If at end of COMPND section, no semicolon to after the molecule(s)
				}

				if ($molecules{$id} =~ /CHAIN: (.*?);/){
					$chains = $1;
				}
				elsif ($molecules{$id} =~ /CHAIN: (.*\w)/){
					$chains = $1;
					## If at end of COMPND section, no semicolon to after the chain(s)
				}

				$chains =~ s/ //g;
				my @chains = split (",", $chains);
				foreach my $chain (@chains){
					if ($molecule){	print OUT "$pdb\t$chain\t$molecule\n"; }
					## Molecules might not be defined if engineered
					else { print OUT "$pdb\t$chain\tundefined molecule\n"; }
				}
			}
		}
	}
}

my $final_count = commify($pdb_count);
my $run_time = (time - $start)/60;
$run_time = sprintf ("%.2f", $run_time);
print "\nIterated through a total of $final_count PDB files\n";
print "Job completed in $run_time minutes.\n\n";

### Subroutine(s)
sub commify {
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text;
}