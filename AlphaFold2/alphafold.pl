#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'alphafold.pl';
my $version = '0.1';
my $updated = '2021-07-19';

use strict; use warnings; use Getopt::Long qw(GetOptions); use POSIX qw(strftime);

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
SYNOPSIS	Runs AlphaFold2 from Google Deepmind in batch mode
REQUIREMENTS	AlphaFold2: https://github.com/deepmind/alphafold

EXAMPLE     ${name} \\
		  -f *.fasta \\
		  -o ./FASTA_3D_ALPHAFOLD \\
		  -m 2021-01-21 \\
		  -c \\
		  -ia /opt/alphafold \\
		  -io /media/Data_1/alphafold_results

OPTIONS:
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-m (--max_date)		--max_template_date option (YYYY-MM-DD) from AlphaFold2 [Default: current date]
-c (--casp14)		CASP14 preset flag
-ai (--alpha_in)	AlphaFold2 installation directory
-ao (--alpha_out)	AlphaFold2 output directory

NOTE: The -ia and -ao command line options are not required if the \$ALPHA_IN and \$ALPHA_OUT environment variables are set.
OPTIONS
die "\n$usage\n" unless @ARGV;

my @fasta;
my $outdir;
my $max_date = strftime("%F", localtime);
my $casp14;
my $alpha_in;
my $alpha_out;
GetOptions(
	'f|fasta=s@{1,}' => \@fasta,
	'o|outdir=s' => \$outdir,
	'm|max_date=s' => \$max_date,
	'c|casp14' => \$casp14,
	'ai|alpha_in=s' => \$alpha_in,
	'ao|alpha_out=s' => \$alpha_out,
);

## Checking for AlphaFold2 installation; env variables in perl are loaded in %ENV
print "\n";
if (!defined $alpha_in){
	unless (exists $ENV{'ALPHA_IN'}){
		print "WARNING: ";
		print "The AlphaFold2 installation directory is not set as an environment variable (\$ALPHA_IN) and the -ai option was not entered.\n";
		print "Please check if AlphaFold2 was installed properly\n\n";
		exit;
	}
}
elsif (defined $alpha_in){
	unless (-d $alpha_in){
		print "WARNING: ";
		print "Could not find AlphaFold2 installation folder: $alpha_in. Please check command line\n\n";
	}
	else {
		unless (-r $alpha_in){
			print "WARNING: ";
			print "Could not read the content of AlphaFold2 installation folder: $alpha_in. Please check file permissions\n\n";
		}
	}
}
if (!defined $alpha_out){
	unless (exists $ENV{'ALPHA_OUT'}){
		print "WARNING: ";
		print "The AlphaFold2 output directory is not set as an environment variable (\$ALPHA_OUT) and the -ao option was not entered.\n";
		print "Please check if AlphaFold2 was installed properly\n\n";
		exit;
	}
}
elsif (defined $alpha_out){
	unless (-d $alpha_out){
		print "WARNING: ";
		print "Could not find AlphaFold2 output folder: $alpha_out. Please check command line\n\n";
	}
	else {
		unless (-r $alpha_in){
			print "WARNING: ";
			print "Could not read the content of AlphaFold2 output folder: $alpha_out. Please check file permissions\n\n";
		}
	}
}

## Checking output directory
unless (-d $outdir){
	mkdir ($outdir, 0755) or die "Can't create $outdir: $!\n";
}

## Chekcing if CASP14 is requested
my $c14 = '';
if ($casp14){ $c14 = '--preset=casp14'; }

## Running AlphaFold2 docker image
while (my $fasta = shift @fasta){

	my ($prefix) = $fasta =~ /^(\w+)/; ## test alaphafold with different names

	my $time = localtime;
	print "$time: working on $fasta\n";

	system "python3 $alpha_in/docker/run_docker.py \\
		--fasta_paths=$fasta \
		--max_template_date=$max_date \\
		$c14";

	system "cp -R \\
		$alpha_out/$prefix \\
		$outdir/"; 

}
