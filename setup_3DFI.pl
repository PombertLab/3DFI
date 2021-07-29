#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'setup_3DFI.pl';
my $version = '0.1b';
my $updated = '2021-07-29';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename; use Cwd qw(abs_path); 

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Adds 3DFI environment variables to configuration file

EXAMPLE     ${name} \\
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

## Capturing absolute paths
my $abs_path_3DFI = abs_path($path_3DFI);
my $abs_path_config = abs_path($config_file);

## Verbosity
print "\n3DFI installation directory: $abs_path_3DFI\n";
print "Configuration file to edit: $abs_path_config\n\n";
print "\# Setting 3DFI environment variables as:\n";
set_env(\*STDOUT);

## Adding to config file
open CONFIG, ">>", "$abs_path_config" or die "Can't open $abs_path_config: $!\n";
print CONFIG "\n".'### 3DFI environment variables'."\n";
set_env(\*CONFIG);

## subroutine
sub set_env {
	my $fh = shift;
	print $fh "export TDFI=$abs_path_3DFI\n";
	print $fh "export RX_3DFI=$abs_path_3DFI/Prediction/RaptorX\n";
	print $fh "export TR_3DFI=$abs_path_3DFI/Prediction/trRosetta\n";
	print $fh "export AF_3DFI=$abs_path_3DFI/Prediction/AlphaFold2\n";
	print $fh "export RF_3DFI=$abs_path_3DFI/Prediction/RoseTTAFold\n";
	print $fh "export HS_3DFI=$abs_path_3DFI/Homology_search\n";
	print $fh "export VZ_3DFI=$abs_path_3DFI/Visualization\n\n";
}