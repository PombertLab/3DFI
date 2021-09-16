#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'create_3DFI_db.pl';
my $version = '0.2';
my $updated = '2021-09-05';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename; use Cwd qw(abs_path); 

my $usage = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Downloads RCSB PDB files with rsync [~36 Gb] and 
			creates/updates a GESAMT archive from these files

EXAMPLE		${name} \\
		  -c 10 \\
		  -d /media/FatCat/databases/3DFI

OPTIONS:
-c (--cpu)	Number of CPUs to create/update the GESAMT archive
-d (--db)	Target 3DFI database location ## Not required if \$TDFI_DB is set.
OPTIONS
die "\n$usage\n" unless @ARGV;

my $cpu;
my $database;
GetOptions(
	'c|cpu=i' => \$cpu,
	'd|db=s' => \$database
);

unless ($cpu){
	print "\n[E] Please specify a number of cpu cores with -c.\n\n";
	exit;
} 

## Checking for $TDFI_HOME environment variable
my $home_3DFI;
if (exists $ENV{'TDFI_HOME'}){ $home_3DFI = $ENV{'TDFI_HOME'}; }
else {
	# If not set, capture it from the running script $0
	my $current_path = abs_path($0);
	($name,$home_3DFI) = fileparse($current_path);
	$home_3DFI =~ s/\/$//;
}

my $homology_dir = "$home_3DFI/Homology_search/";

## Checking for $TDFI_DB environment variable
if ($database) { print "\nSetting database location to: $database\n"; }
elsif (exists $ENV{'TDFI_DB'}){ 
	$database = $ENV{'TDFI_DB'};
	print "\nFound \$TDFI_DB variable. Setting database location to: $ENV{'TDFI_DB'}\n";
}
else {
	print "No environment variable \$TDFI_DB was found and the -d (--db) option was not entered.\n";
	print "Exiting now...\n";
	exit;
}

my $PDB = "$database/RCSB_PDB";
my $GESAMT = "$database/RCSB_GESAMT";

## Check output dir
unless (-d $database){ mkdir ($database, 0755) or die "Can't create $database: $!\n"; }

## Creating log file
my $logfile = "$database/last_updated.log";
open LOG, ">", "$logfile" or die "Can't open $logfile: $!\n";

my $time = localtime;
print LOG "# $time: Creating/updating 3DFI databases:\n";

### Downloading the RCSB PDB database
$time = localtime;
print "\n# $time: Downloading/updating the RCSB PDB database with rsync\n\n";
print LOG "# $time: - Downloading/updating the RCSB PDB database with rsync.\n";
sleep(2);
system "$homology_dir"."update_PDB.pl \\
		-o $PDB \\
		-n 15 \\
		-v";

### Creating a list of titles and chains from PDB files
$time = localtime;
print "\n# $time: Creating/updating the list of titles and chains from the PDB files\n\n";
print LOG "# $time: - Creating/updating the list of titles and chains from the PDB files.\n";
sleep(2);
system "$homology_dir"."PDB_headers.pl \\
		-p $PDB \\
		-o $database/RCSB_PDB_titles.tsv \\
		-v 1000";

### Working with GESAMT
# If found, update the GESAMT archive
$time = localtime;
if (-d $GESAMT){
	print "\n# $time: Updating the RCSB_GESAMT archive\n\n";
	print LOG "# $time: - Updating the RCSB_GESAMT archive.\n";
	sleep(2);
	system "$homology_dir"."run_GESAMT.pl \\
			-cpu $cpu \\
			-update \\
			-arch $GESAMT \\
			-pdb $PDB";
}
# If not, create the GESAMT archive
else {
	print "\n# $time: Creating the RCSB_GESAMT archive\n\n";
	print LOG "# $time: - Creating the RCSB_GESAMT archive.\n";
	sleep(2);
	system "$homology_dir"."run_GESAMT.pl \\
			-cpu $cpu \\
			-make \\
			-arch $GESAMT \\
			-pdb $PDB";
}

$time = localtime;
print LOG "# $time: Tasks completed.\n\n";
