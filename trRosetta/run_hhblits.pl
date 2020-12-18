#!/usr/bin/perl
## Pombert Lab 2020
my $version = 0.1;
my $name = 'run_hhblits.pl';

use strict; use warnings; use Getopt::Long qw(GetOptions);
my @command = @ARGV; ## Keeping track of command line for log

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		$name
VERSION		$version
SYNOPSIS	Runs hhblits on provided fasta files to create .a3m files
REQUIREMENTS	HH-suite3 - https://github.com/soedinglab/hh-suite
                UNICLUST database - https://uniclust.mmseqs.com/

COMMAND       $name -t 10 -f FASTA/ -o HHBLITS/ -e 1e-40 1e-10 1e-03 -d /media/Data_3/Uniclust/UniRef30_2020_06

OPTIONS:
-t (--threads)	    Number of threads to use [Default: 10]
-f (--fasta)	    Folder containing fasta files
-o (--output)	    Output folder
-e (--evalues)      Desired evalues to query
-d (--database)     Uniclust database to query
-n (--num_it)       Number of hhblits iteration [Default: 3]
-v (--verbosity)    hhblits verbosity; 0, 1 or 2 [Default: 2]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $threads = 10;
my $dir;
my $out;
my @evalues;
my $uniclust;
my $nint = 3;
my $verb = 2;
GetOptions(
	't|threads=i' => \$threads,
    'f|fasta=s' => \$dir,
    'o|output=s' => \$out,
    'e|evalues=s@{1,}' => \@evalues,
    'd|database=s' => \$uniclust,
    'n|num_it=i' => \$nint,
    'v|verbosity=i' => \$verb
);

## Reading from folder
if (!defined $out){$out = './';}
unless (-d $out){mkdir $out;}
opendir (DIR, $dir) or die $!;
my @fasta;
while (my $fasta = readdir(DIR)){
		if (($fasta eq '.') || ($fasta eq '..')){next;}
        elsif ($fasta =~ /.hhr$/){next;} ## Skipping previous hhblits results, if any
		else{push (@fasta, $fasta);}
}
@fasta = sort@fasta;

## Running hhblits
my $start = localtime();
open LOG, ">", "$out/hhblits.log";
print LOG "COMMAND LINE:\n$name @command\n"."$name version = $version\n";
print LOG "hhblits search(es) started on: $start\n";
while (my $fasta = shift@fasta){
    my ($prefix, $ext) = $fasta =~ /^(\S+)\.(\w+)$/;
    foreach my $eval (@evalues){
        print "\nWorking on file $dir/$fasta with evalue $eval ...\n\n";
        system "hhblits -cpu $threads -i $dir/$fasta -oa3m $out/$prefix.$eval.a3m -d $uniclust -e $eval -n $nint -v $verb";
    }
}
my $mend = localtime();
print LOG "hhblits search(es) completed on $mend\n\n";
