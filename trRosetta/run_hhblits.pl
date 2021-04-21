#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.2c';
my $name = 'run_hhblits.pl';
my $updated = '2021-04-21';

use strict; use warnings; use Getopt::Long qw(GetOptions);
my @command = @ARGV; ## Keeping track of command line for log

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Runs hhblits on provided fasta files to create .a3m files
REQUIREMENTS	HH-suite3 - https://github.com/soedinglab/hh-suite
		UNICLUST database - https://uniclust.mmseqs.com/

COMMAND		${name} \\
		  -t 10 \\
		  -f FASTA_OL/ \\
		  -o HHBLITS/ \\
		  -d /media/Data_3/Uniclust/UniRef30_2020_06 \\
		  -e 1e-40 1e-10 1e-03

OPTIONS:
-t (--threads)		Number of threads to use [Default: 10]
-f (--fasta)		Folder containing fasta files
-o (--output)		Output folder [Default: ./]
-d (--database)		Uniclust database to query
-v (--verbosity)	hhblits verbosity; 0, 1 or 2 [Default: 2]

## E-value options
-e (--evalues)		Desired evalue(s) to query independently
-s (--seq_it)		Iterates sequentially through evalues
-se (--seq_ev)		Evalues to iterate through sequentially [Default:
			1e-70 1e-60 1e-50 1e-40 1e-30 1e-20 1e-10 1e-08 1e-06 1e-04 1e+01 ]
-ne (--num_it)		# of hhblits iteration per evalue (-e) [Default: 3]
-ns (--num_sq)		# of hhblits iteration per sequential evalue (-s) [Default: 1] 
OPTIONS
die "\n$USAGE\n" unless @ARGV;

## Defining options
my $threads = 10;
my $dir;
my $out = './';
my $uniclust;
my $verb = 2;
my @evalues;
my $sqit;
my @seqev;
my $nint = 3;
my $nseq = 1;
GetOptions(
	't|threads=i' => \$threads,
	'f|fasta=s' => \$dir,
	'o|output=s' => \$out,
	'd|database=s' => \$uniclust,
	'v|verbosity=i' => \$verb,
	'e|evalues=s@{1,}' => \@evalues,
	's|seq_it'  => \$sqit,
	'se|seq_ev=s@{1,}' => \@seqev,
	'ne|num_it=i' => \$nint,
	'ns|num_sq=i' => \$nseq
);

## Reading from folder
unless (-d $out){mkdir ($out,0755) or die "Can't create folder $out: $!\n";}
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
	## Running independent searches per evalue
	if (@evalues){
		foreach my $eval (@evalues){
			print "\nWorking on file $dir/$fasta with evalue $eval ...\n\n";
			system "hhblits \\
			  -cpu $threads \\
			  -i $dir/$fasta \\
			  -oa3m $out/$prefix.$eval.a3m \\
			  -d $uniclust \\
			  -e $eval \\
			  -n $nint \\
			  -v $verb";
		}
	}
	## Running iterative searches, from stricter to more permissive evalues
	if ($sqit){
		
		my $filename = "$out/$prefix.sqit.a3m";
		my @seqit = (1e-70, 1e-60, 1e-50, 1e-40, 1e-30, 1e-20, 1e-10, 1e-08, 1e-06, 1e-04, 1e+01);
		if (@seqev){@seqit = @seqev;}
		my $start = shift@seqit;
		
		if(-f $filename){
			print "File $filename exists, skipping...\n";
			next;
		}

		print "\nIterating on file $dir/$fasta with evalue $start ...\n\n";
		system "hhblits \\
		  -cpu $threads \\
		  -i $dir/$fasta \\
		  -oa3m $filename \\
		  -d $uniclust \\
		  -e $start \\
		  -n $nseq \\
		  -v $verb";
		
		foreach my $eval (@seqit){
			print "\nIterating on file $dir/$fasta with evalue $eval ...\n\n";
			system "hhblits \\
			  -cpu $threads \\
			  -i $filename \\
			  -oa3m $filename \\
			  -d $uniclust \\
			  -e $eval \\
			  -n $nseq \\
			  -v $verb";
		}
	}
}
my $mend = localtime();
print LOG "hhblits search(es) completed on $mend\n\n";
