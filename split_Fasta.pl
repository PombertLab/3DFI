#!/usr/bin/perl
## Pombert Lab 2020
my $version = 0.1;
my $name = 'split_Fasta.pl';

use strict; use warnings;
use PerlIO::gzip; use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Splits a multifasta file into separate files, one per sequence
		
USAGE EXAMPLE	$name -f file.fasta -o output_folder -e fasta

OPTIONS:
-f (--fasta)	FASTA input file (supports gzipped files)
-o (--output)	Output directory; defaults to file name prefix
-e (--ext)	Desired file extension [Default: fasta]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $fasta;
my $out;
my $ext = 'fasta';
GetOptions(
	'f|fasta=s' => \$fasta,
	'o|output=s' => \$out,
	'e|ext=s'	=> \$ext
);

## Creating output folder
if (!defined $out){
	if ($fasta =~ /.gz$/){($out) = $fasta =~ /^(.*?).\w+.gz$/;}
	else{($out) = $fasta =~ /^(.*?).\w+$/;}
}
if (-e $out){
	print "Folder $out already exists... Do you want to continue? (y or n)\n";
	my $answer = <STDIN>;
	chomp $answer; $answer = lc($answer);
	if ($answer eq 'n'){die "Stopping as requested\n";}
}
else {mkdir $out or die "Can't create folder: $out. Please check file permissions\n";}

## Working on multifasta file
my $gzip = ''; if ($fasta =~ /.gz$/){$gzip = ':gzip';}
open FASTA, "<$gzip", "$fasta" or die "Can't open FASTA file: $fasta\n";
my %sequences; my $seq;
while (my $line = <FASTA>){
	chomp $line;
	if ($line =~ />(\S+)/){$seq = $1; print "$seq\n";}
	else {$sequences{$seq} .= $line;}
}
if ($gzip eq ':gzip'){binmode FASTA, ":gzip(none)";}

## working on sequences
for (keys %sequences){
	open OUT, ">", "$out/$_.$ext" or die "Can't create FASTA file: $fasta in folder $out\n";
	print OUT ">$_\n";
	my @fsa = unpack ("(A60)*", $sequences{$_});
	while (my $fsa = shift @fsa){print OUT "$fsa\n";}
	close OUT;
}