#!/usr/bin/perl
## Pombert Lab, 2022
my $name = 'get_pLDDTs.pl';
my $version = '0.1a';
my $updated = '2022-03-02';

use strict;
use warnings;
use File::Basename;
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);

my $usage = <<"USAGE";
NAME		${name}
VERSION		${version}
SYNOPSIS	Generates a tab-delimited table of pLDDTs scores for each AlphaFold model
		from the ranking_debug.json files.

COMMAND		${name} -a AlphaFold_results/ -o AlphaFold_summary.tsv

OPTIONS:
-a (--adir)	AlphaFold results directory/directories
-o (--out)	Output file
USAGE
die "\n$usage\n" unless @ARGV;

my @adir;
my $outfile;
GetOptions(
	'a|adir=s@{1,}' => \@adir,
	'o|out=s' => \$outfile
);

## Creating outdir if needed
if ($outfile){
	my ($filename,$path) = fileparse($outfile);
	if (defined $path){
		unless(-d $path){
			make_path($path,{mode=>0755});
		}
	}
	open OUTFILE, ">", $outfile or die "Can't create $outfile: $!\n";
}

my %af_results;

## Reading AlphaFold directory
while (my $adir = shift@adir){
	opendir (ADIR, $adir) or die "Can't open $adir: $!\n";
	while (my $dname = readdir(ADIR)) {
		if (-d "$adir/$dname"){
			unless (($dname eq '.') or ($dname eq '..')){
				## Checking if .json file is in AlphaFold subdir
				my $json = "$adir/$dname/ranking_debug.json";
				if (-e $json){
					open JSON, "<", $json or die "Can't open $json: $!\n";
					my %plDDTs;
					my $flag;
					my $rank = 0;
					while (my $line = <JSON>){
						chomp $line;
						if ($line =~ /\"(model_\d)\": (.*)/){
							my $model = $1;
							my $plDDT = $2;
							$plDDT =~ s/,//;
							$plDDTs{$model} = $plDDT;
						}
						elsif ($line =~ /\"order\"\:/){
							$flag = 'order';
						}
						elsif ($line =~ /"(model_\d)"/){
							my $model = $1;
							if ($flag eq 'order'){
								my $mnum = $rank + 1;
								$af_results{$dname}{$mnum}{'3DFI'} = "${dname}-m$mnum.pdb";
								$af_results{$dname}{$mnum}{'plDDT'} = $plDDTs{$model};
								$af_results{$dname}{$mnum}{'ranked'} = "ranked_$rank.pdb";
								$af_results{$dname}{$mnum}{'unranked'} = "unrelaxed_$model.pdb";
								$rank++;
							}
						}

					}
				}
				else {
					print STDERR "No .json file for $dname in $adir => no ranked models ?!\n";
				}
			}
		}
	}
}

## Creating output file
print OUTFILE "### Protein\t3DFI name\tplDDT score\tAlphaFold ranked name\tAlphaFold unranked name\n";
foreach my $key (sort (keys %af_results)){
	for (1..5){
		print OUTFILE "$key\t";
		print OUTFILE "$af_results{$key}{$_}{'3DFI'}\t";
		print OUTFILE "$af_results{$key}{$_}{'plDDT'}\t";
		print OUTFILE "$af_results{$key}{$_}{'ranked'}\t";
		print OUTFILE "$af_results{$key}{$_}{'unranked'}\n";
	}
}
