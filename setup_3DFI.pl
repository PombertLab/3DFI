#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'setup_3DFI.pl';
my $version = '0.3';
my $updated = '2021-08-17';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename; use Cwd qw(abs_path); 

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Adds 3DFI environment variables to configuration file

EXAMPLE		${name} \\
		  -p /path/to/3DFI \\
		  -c ~/.bashrc

OPTIONS:
-p (--path)	Path to 3DFI installation directory [Default: ./]
-c (--config)	Configuration file to edit
OPTIONS
die "\n$usage\n" unless @ARGV;

my $path_3DFI = "./";
my $config_file;
GetOptions(
	'p|path=s' => \$path_3DFI,
	'c|config=s' => \$config_file
);

## Checking for config file
if (!defined $config_file){
	die "\nPlease provide a configuration file to edit with the -c option: e.g. -c ~/.bashrc\n\n";
}

## Checking if 3DFI environment variables (or vars with same names) are already set
my $env_flag = 0;
if (exists $ENV{'TDFI'}){  print "\nEnv. variable \$TDFI already set to $ENV{'TDFI'}\n"; }
if (exists $ENV{'RX_3DFI'}){  print "Env. variable \$RX_3DFI already set to $ENV{'RX_3DFI'}\n"; $env_flag = 1; }
if (exists $ENV{'TR_3DFI'}){  print "Env. variable \$TR_3DFI already set to $ENV{'TR_3DFI'}\n"; $env_flag = 1; }
if (exists $ENV{'TR2_3DFI'}){  print "Env. variable \$TR2_3DFI already set to $ENV{'TR2_3DFI'}\n"; $env_flag = 1; }
if (exists $ENV{'AF_3DFI'}){  print "Env. variable \$AF_3DFI already set to $ENV{'AF_3DFI'}\n"; $env_flag = 1; }
if (exists $ENV{'RF_3DFI'}){  print "Env. variable \$RF_3DFI already set to $ENV{'RF_3DFI'}\n"; $env_flag = 1; }
if (exists $ENV{'HS_3DFI'}){  print "Env. variable \$HS_3DFI already set to $ENV{'HS_3DFI'}\n"; $env_flag = 1; }
if (exists $ENV{'VZ_3DFI'}){  print "Env. variable \$VZ_3DFI already set to $ENV{'VZ_3DFI'}\n"; $env_flag = 1; }

if ($env_flag == 1){
	print "\nOne (or more) 3DFI environment variable(s) is already set. Do you wish to continue (y/n)?\n\n";
	my $answer;
	ANSWER: {
		$answer = <STDIN>;
		chomp $answer;
		$answer = lc($answer);
		if (($answer eq 'y') or ($answer eq 'yes')){ next; }
		elsif (($answer eq 'n') or ($answer eq 'no')){ print "\nExiting as requested...\n"; exit; }
		else {
			print "\nUnrecognized answer: $answer\n. Please try again...\n";
			goto ANSWER;
		}
	}
}

## Capturing absolute paths
my $abs_path_3DFI = abs_path($path_3DFI);
my $abs_path_config = abs_path($config_file);

## Verbosity
print "\n3DFI installation directory: $abs_path_3DFI\n";
print "Configuration file to edit: $abs_path_config\n\n";
print "\# Setting 3DFI environment variables as:\n";
set_env(\*STDOUT);

## Adding environment variables and PATH to configuration file
open CONFIG, ">>", "$abs_path_config" or die "Can't open $abs_path_config: $!\n";
set_env(\*CONFIG);
set_path(\*CONFIG);

## subroutine
sub set_env {
	my $fh = shift;
	print $fh "\n".'### 3DFI environment variables'."\n";
	print $fh "export TDFI=$abs_path_3DFI\n";
	print $fh "export RX_3DFI=$abs_path_3DFI/Prediction/RaptorX\n";
	print $fh "export TR_3DFI=$abs_path_3DFI/Prediction/trRosetta\n";
	print $fh "export TR2_3DFI=$abs_path_3DFI/Prediction/trRosetta2\n";
	print $fh "export AF_3DFI=$abs_path_3DFI/Prediction/AlphaFold2\n";
	print $fh "export RF_3DFI=$abs_path_3DFI/Prediction/RoseTTAFold\n";
	print $fh "export HS_3DFI=$abs_path_3DFI/Homology_search\n";
	print $fh "export VZ_3DFI=$abs_path_3DFI/Visualization\n";
	print $fh "export MISC_3DFI=$abs_path_3DFI/Misc_tools\n\n";
}
sub set_path {
	my $fh = shift;
	print $fh "\n".'### 3DFI PATH variables'."\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/RaptorX\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/trRosetta\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/trRosetta2\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/AlphaFold2\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/RoseTTAFold\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Homology_search\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Visualization\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Misc_tools\n";
	print $fh "\nexport PATH\n\n";
}