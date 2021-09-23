#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.2';
my $name = 'rename_files.pl';
my $updated = '2021-03-12';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Rename file(s) using regular expressions 
		
USAGE EXAMPLE	${name} \\
		  -o 'i{0,1}-t26_1-p1' \\
		  -n '' \\
		  -f *.fasta

OPTIONS:
-o (--old)	Old pattern/regular expression to replace with new pattern
-n (--new)	New pattern to replace with; defaults to blank [Default: '']
-f (--files)	Files to rename
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $old;
my $new = '';
my @files;
GetOptions(
	'o|old=s' => \$old,
	'n|new=s' => \$new,
	'f|files=s@{1,}' => \@files
);

while (my $file = shift @files){
	my $nfile = $file;
	$nfile =~ s/$old/$new/;
	print "Renaming $file to $nfile\n";
	system "mv $file $nfile";
}  