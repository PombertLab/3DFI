#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'setup_3DFI.pl';
my $version = '0.4 WIP';
my $updated = '2021-09-04';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename; use Cwd qw(abs_path); 

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Adds 3DFI environment variables to the specified configuration file

EXAMPLE		${name} \\
		  -c ~/.bashrc \\
		  -p /path/to/3DFI \\
		  -d /path/to/3DFI_databases

OPTIONS:
-c (--config)	Configuration file to edit/create
-p (--path)	3DFI installation directory (\$TDFI_HOME) [Default: ./]
-d (-db)	Desired 3DFI database location (\$TDFI_DB)

## Protein structure predictor(s)
--raptorx	RaptorX installation directory
--rosetta	RoseTTAFold installation directory
--alphain	AlphaFold installation directory
--alphaout	AlphaFold output directory
OPTIONS
die "\n$usage\n" unless @ARGV;

my $path_3DFI = "./";
my $config_file;
my $database;
my $raptorx_home;
my $rosettafold_home;
my $alphafold_home;
my $alphafold_out;
GetOptions(
	'p|path=s' => \$path_3DFI,
	'c|config=s' => \$config_file,
	'd|db=s' => \$database,
	'raptorx=s' => \$raptorx_home,
	'rosetta=s' => \$rosettafold_home,
	'alphain=s' => \$alphafold_home,
	'alphaout=s' => \$alphafold_out
);

##### Checking for config file
if (!defined $config_file){
	print "\nPlease provide a configuration file to edit with the -c option: e.g.\n";
	print "~/.bashrc or /etc/profile.d/3DFI.sh\n\n";
	exit;
}

##### Capturing absolute paths
my $abs_path_3DFI = abs_path($path_3DFI);
my $abs_path_config = abs_path($config_file);
my $abs_path_db = abs_path($database);

##### Checking for 3DFI environment variables
if ((exists $ENV{'TDFI_HOME'}) and (exists $ENV{'TDFI_DB'})){ 
	print "Found \$TDFI_HOME as $ENV{'TDFI_HOME'}.\n";
	print "Found \$TDFI_DB as $ENV{'TDFI_DB'}.\n";
	print "Do you want to continue? y/n (y => proceed; n => exit):";
	AUTODETECT:{
		my $answer = <STDIN>;
		chomp $answer;
		my $check = lc ($answer);
		if (($check eq 'y') or ($check eq 'yes')){
			print "\# Setting 3DFI environment variables as:\n";
			open CONFIG, ">>", "$abs_path_config" or die "Can't open $abs_path_config: $!\n";
			set_main(\*STDOUT);
			set_main(\*CONFIG);
		}
		elsif (($check eq 'n') or ($check eq 'no')){
			print "Exiting setup as requested\n";
			exit;
		}
		else {
			print "Unrecognized answer: $answer. Please enter y (yes) or n (no).\n";
			goto AUTODETECT;
		}
	}
}

##### Checking entries
print "\n";
print "Configuration file to edit/create:"."\t"."\t"."$abs_path_config\n\n";
print "3DFI installation directory (\$TDFI_HOME):"."\t"."$abs_path_3DFI\n";
print "3DFI database directory (\$TDFI_DB):"."\t"."\t"."$abs_path_db\n";
print "\n";
if ($raptorx_home){ print "RAPTORX_HOME=$raptorx_home\n"; }
if ($rosettafold_home){ print "ROSETTAFOLD_HOME=$rosettafold_home\n"; }
if ($alphafold_home){ print "ALPHAFOLD_HOME=$alphafold_home\n"; }
if ($alphafold_out){ print "ALPHAFOLD_OUT=$alphafold_out\n"; }

print "\nIs this correct? y/n (y => proceed; n => exit): ";
MAINVARS:{
	my $answer = <STDIN>;
	chomp $answer;
	my $check = lc ($answer);
	if (($check eq 'y') or ($check eq 'yes')){
		open CONFIG, ">>", "$abs_path_config" or die "Can't open $abs_path_config: $!\n";
		set_main(\*CONFIG);
	}
	elsif (($check eq 'n') or ($check eq 'no')){
		print "Exiting setup as requested\n";
		exit;
	}
	else {
		print "Unrecognized answer: $answer. Please enter y (yes) or n (no).\n";
		goto MAINVARS;
	}
}

## Adding ALPHAFOLD, ROSETTAFOLD and/or RAPTORX to contig file
if (($raptorx_home) or ($rosettafold_home) or ($alphafold_home)){
	print CONFIG "\n".'### 3DFI environment variables for protein structure predictor(s)'."\n";
}
if ($raptorx_home){
	print CONFIG "export RAPTORX_HOME=$raptorx_home\n";
}
if ($rosettafold_home){
	print CONFIG "export ROSETTAFOLD_HOME=$rosettafold_home\n";
}
if ($alphafold_home){
	print CONFIG "export ALPHAFOLD_HOME=$alphafold_home\n";
}
if ($alphafold_out){
	print CONFIG "export ALPHAFOLD_OUT=$alphafold_out\n";
}

## Adding environment variables and PATH to configuration file (if yes)
print "Do you want to add the 3DFI installation folder and its ";
print "subdirectories to the \$PATH environment variable? y/n: ";
PATHVARS:{
	my $answer = <STDIN>;
	chomp $answer;
	my $check = lc ($answer);
	if (($check eq 'y') or ($check eq 'yes')){
		open CONFIG, ">>", "$abs_path_config" or die "Can't open $abs_path_config: $!\n";
		set_path(\*CONFIG);
	}
	elsif (($check eq 'n') or ($check eq 'no')){
		print "Skipping additions to the \$PATH environment variable.\n";
		next;
	}
	else {
		print "Unrecognized answer: $answer. Please enter y (yes) or n (no).\n";
		goto PATHVARS;
	}
}

print "\n";
exit;

##### subroutines
sub set_main {
	my $fh = shift;
	print $fh "\n".'### 3DFI environment variables'."\n";
	print $fh "export TDFI_HOME=$abs_path_3DFI\n";
	print $fh "export TDFI_DB=$abs_path_db\n";
}

sub set_path {
	my $fh = shift;
	print $fh "\n".'### 3DFI PATH variables'."\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI\n";
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
