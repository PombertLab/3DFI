#!/usr/bin/perl
## Pombert Lab 2022
my $version = '0.1a';
my $name = 'PDB_ligands.pl';
my $updated = '2022-04-12';

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
SYNOPSIS	Generates a Tab-delimited list of PDB structures with ligands from
		the RCSB Chemical Component Dictionary (components.cif.gz)

REQUIREMENTS	PDB files downloaded from RCSB PDB; e.g. pdb2zvl.ent.gz
		PerlIO::gzip
		https://ftp.wwpdb.org/pub/pdb/data/monomers/components.cif.gz
		
USAGE EXAMPLE	${name} \\
		  -p RCSB_PDB/ RCSB_PDB_obsolete/ \\
		  -l components.cif.gz \\
		  -o RCSB_PDB_ligands.tsv \\
		  -v 1000

OPTIONS:
-p (--pdb)	Directories containing PDB files downloaded from RCSB PDB/PDBe (gzipped)
-l (--ligand)	RCSB ligand dictionary in mmCIF format
-o (--output)	Output file in tsv format
-f (--force)	Regenerate all PDB titles ## Default off
-v (--verbose)	Prints progress every X file [Default: 1000]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @pdbs;
my $ligands;
my $rcsb_list;
my $force;
my $verbose = 1000;
GetOptions(
	'p|pdb=s@{1,}' => \@pdbs,
	'l|ligand=s' => \$ligands,
	'o|output=s' => \$rcsb_list,
	'f|force' => \$force,
	'v|verbose=i' => \$verbose
);

## Creating ligand code => name database from RCSB ligand dictionary
open LIG, "<:gzip", $ligands or die "Can't open $ligands: $!\n";

print "\nParsing $ligands...\n\n";

my %chem_dic;

# some of the data is multiline, concatenating the data accordingly
my %data;
my $data_name;
my $flag = 0;
while (my $line = <LIG>){
	chomp $line;
	if ($line =~ /^data_(\S+)/){
		$data_name = $1;
		$flag = 1;
	}
	elsif ($line =~ /^#/){
		next;
	}
	elsif ($line =~ /^_chem_comp\.(\w+)/){
		$data{$data_name} .= $line;
	}
	elsif ($line =~ /^loop_/){
		$flag = 0;
	}
	elsif ($flag == 1){
		$data{$data_name} .= $line;
	}
}

# splitting the data per line and removing extra characters
for my $key (sort (keys %data)){
	my @columns = split('_chem_comp.', $data{$key});
	my $id;
	my $product_name; 
	foreach my $line (@columns){
		if ($line =~ /^id\s+(\S+)/){
			$id = $1;
		}
		if ($line =~ /^name/){

			$product_name = $line;
			$product_name =~ s/^name\s+//;
			$product_name =~ s/^\;//;
			$product_name =~ s/\;$//;
			$product_name =~ s/^\"//;
			$product_name =~ s/\"\s*$//;

			$chem_dic{$id} = $product_name;
		}
	}
}

binmode LIG, ":gzip(none)";

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
			my %ligands;

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
				## Getting ligand information
				elsif ($line =~ /^HET\s+(\S+)/){
					my $ligand = $1;
					$ligands{$ligand} = $1;
				}
			}
			binmode PDB, ":gzip(none)";

			## Printing title
			if (defined $title){
				print OUT "$pdb\tTITLE\t$title\n";
			}
			else {
				print STDERR "[W] $pdb is missing a title\n";
			}

			## Printing ligand(s)
			if (scalar (keys %ligands) == 0){
				print OUT "$pdb\tno ligand\n";
			}
			else{
				foreach my $ligand (sort (keys %ligands)){
					print OUT "$pdb\t$ligand\t$chem_dic{$ligand}\n";
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