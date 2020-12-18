#!/usr/bin/perl
## Pombert Lab 2020
my $version = 0.1;
my $name = 'fasta_oneliner.pl';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename;

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Convert FASTA sequences into single string FASTA

COMMAND         $name -f *.fasta -o FASTA_OL

OPTIONS:
-f (--fasta)    FASTA files to convert
-o (--output)   Output folder
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my @fasta;
my $out;
GetOptions(
    'f|fasta=s@{1,}' => \@fasta,
    'o|output=s' => \$out,
);

## Converting fasta files
while (my $fasta = shift@fasta){
    open FASTA, "<", "$fasta";
    my($name, $dir) = fileparse($fasta);
    my $header; my $seq;
    while (my $line = <FASTA>){
        chomp $line;
        if ($line =~ /^>/){$header = $line;}
        else{$seq .= $line;}
    }
    open OUT, ">", "$out/$name";
    print OUT "$header\n"."$seq\n";
    close FASTA; close OUT;
}