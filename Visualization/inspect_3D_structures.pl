#!/usr/bin/perl

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

my $name = "inspect_3D_structures.pl";
my $version = "0.1a";
my $updated = "2021-07-31";

my $usage = << "EXIT";
NAME	${name}
VERSION	${version}
UPDATED	${updated}

SYNOPSIS	The purpose of this script is to visually inspect predicted 3D structures of proteins of interest

USAGE	${name} \\
		  -v 3D_Visualizations

OPTIONS
-v (--3D_vis)	Path to 3D visualizations directory ## created by prepare_visualizations.pl
EXIT
die "\n\n$usage\n\n" unless @ARGV;

my $indir;

GetOptions(
	"v|3D_vis=s" => \$indir,
);

die "\n\n[ERROR]\tPath to 3D visualization directory required\n\n" unless ($indir);

## Load all visuals into database for access/reaccess purposes
my %visuals;
opendir (EXT,$indir) or die "\n\n[ERROR]\tCan't open $indir: $!\n\n";
while (my $locus = readdir(EXT)){
	if (-d "$indir/$locus" && $locus =~ /\w+/){
		opendir (INT,"$indir/$locus") or die "\n\n[ERROR]\tCan't open $indir/$locus: $!\n\n";
		my @files;
		while (my $file = readdir(INT)){
			if ($file =~ /\w+/){
				push(@files,"$file");
			}
		}
		$visuals{$locus} = [@files];
		closedir INT
	}
}

open LOG, ">>", "$indir/visualizations.notes";
system "clear";
my ($filename,$dir) = fileparse($0);
my $script = "$dir/Helper_Scripts/restore_chimerax_session.py";
## Start visualization
my @loci = sort(keys(%visuals));
my $pos = 0;
LOOP: while (0==0){
	## Total amount of options for current locus
	my $options = scalar(@{$visuals{$loci[$pos]}});
	## Infinite loop to allow for typos and unlimited viewing of single locus
	## Escape loop by [a]dvancing, e[x]iting, [r]eviewing previous locus
	print "\n\n\tAvailable 3D visualizations for $loci[$pos]:\n\n";
	my $counter = 1;
	foreach my $vis (@{$visuals{$loci[$pos]}}){
		print "\t\t$counter. $vis\n";
		$counter++;
	}
	print "\n\n\tOptions:\n\n";
	if ($options > 1){
		print "\t\t[1-$options] open corresponding file\n";
	}
	else {
		print "\t\t[1] to open .pdb file\n";
	}
	print "\t\t[a] advance to next locus tag\n";
	print "\t\t[p] return to previous locus tag\n";
	print "\t\t[n] to create a note for locus tag\n";
	print "\t\t[x] to exit 3D inspection\n\n";
	print "\t\tSelection: ";
	chomp (my $selection = <STDIN>);
	if ($selection eq 'a'){
		system "clear";
		$pos++;
		if ($pos > scalar(@loci) - 1){
			$pos = 0;
		}
	}
	elsif ($selection eq 'p'){
		system "clear";
		$pos--;
		if ($pos < -1){
			$pos = scalar(@loci) - 2;
		}
	}
	elsif ($selection eq 'x'){
		last LOOP;
	}
	elsif ($selection eq 'n'){
		print "\n\t\tNotes for $loci[$pos]: ";
		chomp(my $notes = <STDIN>);
		if ($notes =~ /\w+/){
			print LOG "$loci[$pos]\t$notes\n";
		}
		system "clear";
	}
	elsif (($selection =~ /^[0-9]+$/) && (0 < $selection) && ( $selection <= $options)){
		unless ($selection <= $options){
			system "clear";
			print "\n\n\t[ERROR] Invalid Choice: $selection\n";
		}
		my $choice = @{$visuals{$loci[$pos]}}[$selection-1];
		## Adding 2> /dev/null to silence the Release of profile requested but WebEnginePage python warning
		system "chimerax 2> /dev/null $indir/$loci[$pos]/$choice $script &";
		system "clear";
	}
	else {
		system "clear";
		print "\n\n\t[ERROR] Invalid Choice: $selection\n";
	}
}

print "\n\n\t[EXIT] Terminating 3D Visualization\n\n";