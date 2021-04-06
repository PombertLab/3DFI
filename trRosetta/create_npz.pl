#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.1b';
my $name = 'create_npz.pl';
my $updated = '2021-03-12';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Creates .npz files with trRosetta from .a3m files created by hhblits
REQUIREMENTS	trRosetta - https://github.com/gjoni/trRosetta
		tensorflow 1.15 - https://www.tensorflow.org/

NOTES		Probably best to run in a conda environment...
NOTES		Can quickly eat through 8 Gb of VRAM with large a3m files...
NOTES		If so, instead try with: pip install tensorflow-cpu==1.15

COMMAND		${name} \\
		  -a HHBLITS/*.a3m \\
		  -o NPZ/ \\
		  -p /media/Data_3/opt/trRosetta/network/predict.py \\
		  -m /media/Data_3/opt/trRosetta/model2019_07

OPTIONS:
-a (--a3m)	.a3m files generated by hhblits
-o (--output)	Output folder
-p (--predict)	Path to predict.py from trRosetta
-m (--model)	Path to trRosetta model directory
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @a3m;
my $out;
my $pred;
my $model;
GetOptions(
	'a|a3m=s@{1,}' => \@a3m,
	'o|output=s' => \$out,
	'p|predict=s' => \$pred,
	'm|model=s' => \$model
);

## Working on a3m files
if (!defined $out){$out = './';}
unless (-d $out){mkdir ($out,0755) or die "Can't create folder $out: $!\n";}
while (my $a3m = shift@a3m){
	my($name, $dir) = fileparse($a3m);
	my ($prefix) = $name =~ /^(\S+)\.(\w+)$/;
	print "\nWorking on file: $name\n\n";
	system "python $pred -m $model $a3m $out/$prefix.npz";
}



