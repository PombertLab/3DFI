#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'setup_3DFI.pl';
my $version = '0.7';
my $updated = '2021-04-27';

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Cwd qw(abs_path);
use File::Path qw(make_path);

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Installs AlphaFold, Raptorx and/or RoseTTAfold, foldseek, and mican
		and adds the 3DFI environment variables to the specified configuration
		file

EXAMPLE		${name} \\
		  -c ~/.bashrc \\
		  -p /path/to/3DFI \\
		  -d /path/to/3DFI_databases \\
		  -i alphafold raptorx rosettafold \\
		  -pyr ~/Downloads/PyRosetta4.Release.python37.*.tar.bz2

OPTIONS:
-c (--config)	Configuration file to edit/create (e.g. ~/.bashrc)
-w (--write)	Write mode: (a)ppend or (o)verwrite [Default: a]
-p (--path)	3DFI installation directory (\$TDFI_HOME) [Default: ./]
-d (--dbdir)	3DFI databases directory (\$TDFI_DB)

## Protein structure predictors 
-i (--install)		3D structure predictor(s) to install (alphafold raptorx and/or rosettafold)
-pyr (--pyrosetta)	PyRosetta4 [Python-3.7.Release] .tar.bz2 archive to install
			# Download - https://www.pyrosetta.org/downloads#h.xe4c0yjfkl19
			# License - https://els2.comotion.uw.edu/product/pyrosetta

## Docker
-name (--docker_image)	Name of the AlphaFold docker image to build [Default: alphafold_3dfi]
-rebuild		Build/rebuild the docker image with the --pull and --no-cache flags
OPTIONS
die "\n$usage\n" unless @ARGV;

my $config_file;
my $write = 'a';
my $path_3DFI = "./";
my $database;
my @predictors;
my $pyrosetta;
my $docker_image = 'alphafold_3dfi';
my $rebuild_docker;
GetOptions(
	'c|config=s' => \$config_file,
	'w|write=s' => \$write,
	'p|path=s' => \$path_3DFI,
	'd|dbdir=s' => \$database,
	'i|install=s@{1,}' => \@predictors,
	'pyr|pyrosetta=s' => \$pyrosetta,
	'name|docker_image=s' => \$docker_image,
	'rebuild' => \$rebuild_docker
);

######################################################
# Checking for config file & database

# Config file
unless ($config_file){
	print "\n[E] Please provide a configuration file to edit with the -c option: e.g.\n";
	print "~/.bashrc or /etc/profile.d/3DFI.sh\n\n";
	exit;
}

my $write_mode = lc($write);
unless (($write_mode eq 'a') or ($write_mode eq 'o')){
	print "\n[E] Unrecognized write mode: $write. Please use a or o ...\n";
	print "[E] Exiting...\n\n";
	exit;
}

my $diamond = '>>';
if ($write_mode eq 'o'){ $diamond = '>'; }

# Database
unless ($database){
	print "\n[E] Please provide a database location with the -d option: e.g.\n";
	print "-d /media/databases/3DFI\n\n";
	exit;
}
if ($database){
	unless (-d $database){
		make_path($database, { mode => 0755 }) or die "Can't create $database: \n";
	}
}

######################################################
# Checking for requested predictors & dependencies
my %predictor_homes = (
	'raptorx' => 'RAPTORX_HOME',
	'alphafold' => 'ALPHAFOLD_HOME',
	'rosettafold' => 'ROSETTAFOLD_HOME'
);

foreach my $predictor (@predictors){
	$predictor = lc($predictor);
	unless (exists $predictor_homes{$predictor}){
		print "\n[E] Unrecognized predictor: $predictor.\n";
		print "[E] Possible options are alphafold, raptorx and/or rosettafold\n";
		print "[E] Exiting...\n\n";
		exit;
	}
	## Checking for Docker
	if ($predictor eq 'alphafold'){
		check_program('docker', 'AlphaFold');
	}
	## Checking for Conda
	elsif ($predictor eq 'rosettafold'){
		check_program('conda', 'RoseTTAFold');
	}
}

######################################################
# Capturing absolute paths
my $root_dir = `pwd`;
chomp $root_dir;
my $abs_path_3DFI = abs_path($path_3DFI);
my $abs_path_config = abs_path($config_file);
my $abs_path_db = abs_path($database);

######################################################
# Creating default install location for 3D predictors

my $root_3D = "$abs_path_3DFI".'/3D';
unless (-d $root_3D){
	make_path ($root_3D,{mode => 0755}) or die "Can't create $root_3D: $!\n";
}

my $alphafold_home = "$root_3D".'/'.'alphafold';
my $pip_location = "$root_3D/alphafold/python/";
my $raptorx_home = "$root_3D".'/'.'RaptorX';
my $rosettafold_home = "$root_3D".'/'.'RoseTTAFold';

######################################################
# Checking configuration file entries
print "\n";
print "Configuration file to edit/create:"."\t"."\t"."$abs_path_config\n";
print "3DFI installation directory (\$TDFI_HOME):"."\t"."$abs_path_3DFI\n";
print "3DFI database directory (\$TDFI_DB):"."\t"."\t"."$abs_path_db\n";
print "\n";
print "Is this correct? y/n (y => proceed; n => exit): ";
CHECKVARS:{
	my $answer = <STDIN>;
	chomp $answer;
	my $check = lc ($answer);
	if (($check eq 'y') or ($check eq 'yes')){
		next;
	}
	elsif (($check eq 'n') or ($check eq 'no')){
		print "Exiting setup as requested\n\n";
		exit;
	}
	else {
		print "Unrecognized answer: $answer. Please enter y (yes) or n (no).\n";
		goto CHECKVARS;
	}
}

######################################################
# Adding 3DFI environment variables to config file (if yes)
print "Do you want to add the 3DFI environment variables ";
print "to $config_file? y/n: ";

MAINVARS:{
	my $answer = <STDIN>;
	chomp $answer;
	my $check = lc ($answer);
	if (($check eq 'y') or ($check eq 'yes')){
		open CONFIG, "$diamond", "$abs_path_config" or die "Can't open $abs_path_config: $!\n";
		set_main(\*CONFIG);
	}
	elsif (($check eq 'n') or ($check eq 'no')){
		print "Skipping 3DFI environment variables...\n";
		next;
	}
	else {
		print "Unrecognized answer: $answer. Please enter y (yes) or n (no).\n";
		goto MAINVARS;
	}
}

######################################################
# Adding 3DFI dirs to $PATH in config file (if yes)
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

######################################################
# Installing protein structure predictors

foreach my $predictor (@predictors){
	
	$predictor = lc($predictor);
	
	if ($predictor eq 'alphafold'){

		# Using a forked version of AlphaFold. The version was forked to
		# - remove the hard coded output directory
		# - remove the hard coded database directory 
		# - remove the root ownership of files created by AlphaFold
		# - use a CUDA version compatible with CUDA compute capability 8.6

		# Downloading forked version from Git
		print "\nDownloading AlphaFold with git clone\n";
		my $alphafold_git = 'https://github.com/PombertLab/alphafold.git';
		chdir ("$root_3D") or die "cannot change: $!\n";

		# Update with git pull if exists
		if (-d "$root_3D/alphafold/"){
			chdir "$root_3D/alphafold/";
			system "git pull";
			chdir "$root_3D";
		}
		# Otherwize git clone
		else { system "git clone $alphafold_git"; }

		# Creating Docker image + pip install of reqs
		print "\nCreating AlphaFold docker image named $docker_image\n";
		chdir "$root_3D/alphafold/";

		# rebuild flags
		my $docker_rebuild_flags = '';
		if ($rebuild_docker){
			$docker_rebuild_flags = '--pull --no-cache';
		}

		system "docker \\
			build \\
			-f $root_3D/alphafold/docker/Dockerfile \\
			$docker_rebuild_flags \\
			-t $docker_image \\
			.";

		# Creating a pip location for AlphaFold requirements
		unless (-d $pip_location){
			mkdir ($pip_location, 0755) or die "Can't create $pip_location: $!\n";
		}

		print "\nInstalling AlphaFold requirements with pip3\n";
		system "pip3 install \\
			--target=$pip_location \\
			--upgrade \\
			-r $root_3D/alphafold/docker/requirements.txt";

		chdir "$root_3D";

	}

	elsif ($predictor eq 'raptorx') {

		##### RaptorX
		## We would like to thank Professor Jinbo Xu for kindly allowing us
		## to redistribute RaptorX for non-commercial academic purposes!

		my $raptorx_file = 'raptorx.tar.gz';
		my $raptorx_url = 'http://bioinformatics.one/3DFI/raptorx/'."$raptorx_file";

		print "\nDownloading RaptorX [53 Mb] with wget\n";
		system "wget \\
			-P $root_3D \\
			$raptorx_url";

		### Inflating RaptorX tar archive
		system "tar \\
			-zxvf $root_3D/$raptorx_file \\
			-C $root_3D/";

		### Creating symlink to RaptorX databases
		my $symlink = "$root_3D/RaptorX/databases";

		if (-l $symlink){ ## Removing previous link, if any
			system "unlink $symlink";
		}

		system "ln -s \\
			$abs_path_db/RAPTORX/ \\
			$symlink";

		### Running RaptorX setup script
		chdir "$root_3D/RaptorX/";
		system "./setup.pl";
		chdir "$root_dir";

	}

	elsif ($predictor eq 'rosettafold') {

		# Downloading RoseTTAFold from Git
		print "\nDownloading RoseTTAFold with git clone\n";
		my $rosettafold_git = 'https://github.com/RosettaCommons/RoseTTAFold.git';
		chdir ("$root_3D") or die "cannot change: $!\n";

		# Update with git pull if exists
		if (-d "$root_3D/RoseTTAFold/"){
			chdir "$root_3D/RoseTTAFold/";
			system "git pull";
			chdir "$root_3D";
		}
		# Otherwize git clone
		else { system "git clone $rosettafold_git"; }

		# Create RoseTTAFold conda environments CUDA11
		chdir "$root_3D/RoseTTAFold/";
		system "conda env create -f RoseTTAFold-linux.yml";
		system "conda env create -f folding-linux.yml";

		## Install RoseTTAFold dependencies
		system "$root_3D/RoseTTAFold/install_dependencies.sh";

		## Create symlinks to RoseTTAFold databases
		my $weights = "$root_3D/RoseTTAFold/weights";
		my $bfd = "$root_3D/RoseTTAFold/bfd";
		my $uniref30 = "$root_3D/RoseTTAFold/UniRef30_2020_06";
		my $pdb_templates = "$root_3D/RoseTTAFold/pdb100_2021Mar03";

		# bfd
		system "ln -s \\
			$abs_path_db/BFD/ \\
			$bfd";

		# weights
		system "ln -s \\
			$abs_path_db/ROSETTAFOLD/weights \\
			$weights";

		# uniref
		system "ln -s \\
			$abs_path_db/ROSETTAFOLD/UniRef30_2020_06 \\
			$uniref30";

		# templates
		system "ln -s \\
			$abs_path_db/ROSETTAFOLD/pdb100_2021Mar03 \\
			$pdb_templates";

		## Install PyRosetta inside the Conda folding environment
		if ($pyrosetta){
			my $tmpdir = "/tmp/pyrosetta";
			my $install_script = "$abs_path_3DFI/Prediction/RoseTTAFold/install_pyrosetta.sh";
			system "$install_script \\
				$pyrosetta \\
				$tmpdir";
		}

		chdir "$root_dir";

	}

}

######################################################
# Installing Foldseek
print "\nDownloading Foldseek [28 Mb] with wget\n";
my $foldseek_url = "https://mmseqs.com/foldseek/foldseek-linux-avx2.tar.gz";

system "wget \\
	-P $root_3D/ \\
	$foldseek_url";

chdir "$root_3D";
system "tar -zxvf foldseek-linux-avx2.tar.gz";
system "mv ./foldseek/bin/foldseek ./";
system "chmod +x ./foldseek";
system "rm -R ./foldseek/";
chdir "$root_dir";


######################################################
# Installing MICAN

print "\nDownloading MICAN [1.25 Mb] with wget\n";
my $mican_url = "http://landscape.tbp.cse.nagoya-u.ac.jp/MICAN/Download/bin/mican_linux_64";
system "wget \\
	-P $root_3D \\
	$mican_url";
system "mv $root_3D/mican_linux_64 $root_3D/mican";
system "chmod +x $root_3D/mican";

######################################################
# tasks completed
exit;

######################################################
# subroutines
sub check_program {
	my $program = $_[0];
	my $prereq = $_[1];
	my $status = `echo \$(command -v $program)`;
	chomp $status;
	if ($status eq ''){
		print "\n[E] $program not found. $prereq requires $program. Please make sure that $program is properly installed before using setup_3DFI.pl.\n";
		print "[E] Exiting...\n\n";
		exit;
	}
}

sub set_main {
	my $fh = shift;
	my $bar = '#' x 50;
	print $fh "\n"."$bar"."\n";
	print $fh '# 3DFI environment variables'."\n";
	print $fh "\n";
	print $fh "export TDFI_HOME=$abs_path_3DFI\n";
	print $fh "export TDFI_DB=$abs_path_db\n";
	print $fh "\n";
	print $fh "export RAPTORX_HOME=$raptorx_home\n";
	print $fh "export ROSETTAFOLD_HOME=$rosettafold_home\n";
	print $fh "export ALPHAFOLD_HOME=$alphafold_home\n";
	print $fh "export PYTHONPATH=\$PYTHONPATH:$pip_location\n"; ## Check if this breaks python...

}

sub set_path {
	my $fh = shift;
	my $bar = '#' x 50;
	print $fh "\n"."$bar"."\n";
	print $fh '# 3DFI PATH variables'."\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/RaptorX\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/AlphaFold2\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Prediction/RoseTTAFold\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Homology_search\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Visualization\n";
	print $fh "PATH=\$PATH:$abs_path_3DFI/Misc_tools\n";
	print $fh "\nexport PATH\n\n";
}
