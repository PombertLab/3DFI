#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = 'create_3DFI_db.pl';
my $version = '0.5.3';
my $updated = '2023-03-14';

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
SYNOPSIS	Downloads 3DFI databases and creates a Foldseek from the RCSB PDB files.
		Can also create or update a GESAMT database.

REQUIREMENTS	Rsync - https://rsync.samba.org/
		Aria2 - https://aria2.github.io/
		Foldseek - https://github.com/steineggerlab/foldseek

OPTIONAL	GESAMT (from the CCP4 package) - https://www.ccp4.ac.uk/
		## To create/update a GESAMT database

EXAMPLE		${name} --all

OPTIONS:
-a (--all)	Download/create all databases: RCSB, ALPHAFOLD, ROSETTAFOLD, RAPTORX, Foldseek, GESAMT
-d (--db)	Target 3DFI database location [Default: \$TDFI_DB]
-c (--cpu)	Number of CPUs to create/update the Foldseek/GESAMT databases [Default: 10]

# Download/create specific databases:
--rcsb		RCSB PDB + Foldseek + GESAMT
--alpha		AlphaFold2
--raptorx	RaptorX
--rosetta	RoseTTAFold

# Download options
--nconnect	Number of concurrent aria2 connections [Default: 10]
--no_unpack	Do not unpack downloaded files ## Useful for backups
--delete	Delete downloaded archives after unpacking them

# GESAMT options
--make_gesamt	Create a GESAMT archive from the RCSB PDB files instead of 
		downloading a pre-built version
--update_gesamt	Update an existing GESAMT archive made with --make_gesamt

### Approximate download size / disk usage
# TOTAL				669 Gb / 3.2 Tb
# RSCB PDB			39 Gb / 42 Gb inflated
# BFD (AlphaFold/RoseTTAFold)	272 Gb / 1.8 Tb inflated
# AlphaFold (minus BFD)		176 Gb / 0.6 Tb inflated
# RoseTTAFold (minus BFD)	146 Gb / 849 Gb inflated
# RaptorX			37 Gb / 76 Gb inflated
OPTIONS
die "\n$usage\n" unless @ARGV;

my $database;
my $all_databases;
my $rcsb;
my $alphafold;
my $raptorx;
my $rosettafold;
my $aria_connections = 10;
my $no_unpack;
my $delete;
my $cpu = 10;
my $make_gesamt;
my $update_gesamt;
GetOptions(
	'd|db=s' => \$database,
	'a|all' => \$all_databases,
	'rcsb' => \$rcsb,
	'alpha' => \$alphafold,
	'raptorx' => \$raptorx,
	'rosetta' => \$rosettafold,
	'nconnect=i' => \$aria_connections,
	'no_unpack' => \$no_unpack,
	'delete' => \$delete,
	'c|cpu=i' => \$cpu,
	'make_gesamt' => \$make_gesamt,
	'update_gesamt' => \$update_gesamt,
);


################################################
# Checking for $TDFI_HOME environment variable
my $home_3DFI;
if (exists $ENV{'TDFI_HOME'}){ $home_3DFI = $ENV{'TDFI_HOME'}; }
else {
	# If not set, capture it from the running script $0
	my $current_path = abs_path($0);
	($name,$home_3DFI) = fileparse($current_path);
	$home_3DFI =~ s/\/$//;
}

my $homology_dir = "$home_3DFI/Homology_search/";


################################################
# Checking for $TDFI_DB environment variable
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


################################################
# Checking output dir

unless (-d $database){ 
	make_path($database, { mode => 0755 }) or die "Can't create $database: $!\n";
}

# Space on device
my @space_on_device = `df -h $database`;
my $space_on_device = $space_on_device[1]; 
my @disk_usage = split (/\s+/, $space_on_device);
my $space_left = $disk_usage[3];
print "\nSpace available on device = $space_left\n\n";


################################################
# Checking for aria2, unpigz, foldseek and gesamt

# Aria2
my $aria2 = `echo \$(command -v aria2c)`;
chomp $aria2;
if ($aria2 eq ''){
	print "[E] aria2c not found in the \$PATH. Please check if aria2 is installed\n";
	print "[E] To install aria2 on Fedora, type: sudo dnf install aria2\n";
	print "Exiting...\n";
	exit;
}

# Foldseek
if ($rcsb or $all_databases){
	my $fseek = `echo \$(command -v foldseek)`;
	chomp $fseek;
	if ($fseek eq ''){
		print "[E] foldseek not found in the \$PATH. Please check if foldseek is installed\n";
		print "[E] Foldseek is installed automatically in \$TDFI_HOME/3D\n";
		print "[E] Foldseek is available at https://github.com/steineggerlab/foldseek";
		print "Exiting...\n";
		exit;
	}
}

# Pigz
my $decompression_tool = 'gunzip';
my $unpigz = `echo \$(command -v unpigz)`;
chomp $unpigz;
unless ($unpigz eq ''){ $decompression_tool = 'unpigz'; }

# GESAMT
if ($make_gesamt or $update_gesamt){ 
	my $gesamt_prog = `echo \$(command -v gesamt)`;
	chomp $gesamt_prog;
	if ($gesamt_prog eq ''){ 
		print "[E] Cannot find gesamt but --make_gesamt/--update_gesamt was requested. Please install GESAMT in your \$PATH\n\n";
		print "[E] GESAMT is part of the CCP4 package - https://www.ccp4.ac.uk/\n";
		print "[E] Exiting...\n";
		exit;
	}
}

################################################
# RCSB PDB / GESAMT database
if ($rcsb or $all_databases){

	## Subdirectories
	my $PDB = "$database/RCSB_PDB";
	my $PDB_obs = "$database/RCSB_PDB_obsolete";
	my $GESAMT = "$database/RCSB_GESAMT";

	### Downloading/updating the current RCSB PDB database with rsync
	system "$homology_dir"."update_PDB.pl \\
			-o $PDB \\
			-d current \\
			-n 15";

	### Downloading/updating the obsolete RCSB PDB database with rsync
	system "$homology_dir"."update_PDB.pl \\
			-o $PDB_obs \\
			-d obsolete \\
			-n 15";

	### Downloading/updating the list of titles and chains from PDB files
	my $list_file = 'RCSB_PDB_titles_20220223.tar.gz';
	my $list_url = 'http://bioinformatics.one/3DFI/gesamt/'."$list_file";

	aria($list_file, $list_url, $database);
	untar("$database/$list_file", $database);

	# Updating
	system "$homology_dir"."PDB_headers.pl \\
			-p $PDB $PDB_obs \\
			-o $database/RCSB_PDB_titles.tsv \\
			-v 1000";

	## Creating a foldseek database
	my $fskdir = "$database/RCSB_FOLDSEEK";
	unless (-d $fskdir){
		mkdir ($fskdir, 0755) or die "Can't create $fskdir: $!\n";
	}
	system "run_foldseek.pl \\
			-create \\
			-db $fskdir \\
			-pdb $PDB \\
			-threads $cpu \\
			-log $database/foldseek.log";

	### Downloading GESAMT or creating one
	# Create a new GESAMT archive from the RCSB PDB files. Can take a few hours...
	if ($make_gesamt){
		my $time = localtime;
		print "\n# $time: Creating the RCSB_GESAMT archive from downloaded RCSB PDB files\n\n";
		system "$homology_dir"."run_GESAMT.pl \\
				-cpu $cpu \\
				-make \\
				-arch $GESAMT \\
				-pdb $PDB";
	}
	# Update an existing GESAMT archive
	elsif ($update_gesamt){
		my $time = localtime;
		print "\n# $time: Creating the RCSB_GESAMT archive from downloaded RCSB PDB files\n\n";
		system "$homology_dir"."run_GESAMT.pl \\
				-cpu $cpu \\
				-update \\
				-arch $GESAMT \\
				-pdb $PDB";
	}
	# Otherwize, download a pre-built GESAMT archive, much faster (default)
	else {
		my $gesamt_file = 'rcsb_gesamt.tar.gz';
		my $gesamt_url = 'http://bioinformatics.one/3DFI/gesamt/'."$gesamt_file";

		aria($gesamt_file, $gesamt_url, $database);
		untar("$database/$gesamt_file", $database);
	}

}


################################################
# AlphaFold2 / RoseTTAFold bfd database
# Downloading only once 272 GB => 1.8 Tb inflated

if ($alphafold or $rosettafold or $all_databases){

	my $bfd_file = 'bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz';
	my $bfd_url = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/'."$bfd_file";

	my $bfd_dir = "$database/BFD";
	unless (-d $bfd_dir){ mkdir ($bfd_dir, 0755) or die "Can't create $bfd_dir: $!\n"; }

	aria($bfd_file, $bfd_url, $bfd_dir);
	untar("$bfd_dir/$bfd_file", $bfd_dir);

}


################################################
# AlphaFold2 databases

if ($alphafold or $all_databases){

	my $af_dbs = "$database/ALPHAFOLD";
	unless (-d $af_dbs){ mkdir ($af_dbs, 0755) or die "Can't create $af_dbs: $!\n"; }

	##### Creating symlink to bfd inside ALPHAFOLD
	my $symlink = "$af_dbs/bfd";
	if (-l $symlink){ system "unlink $symlink";	}

	system "ln -s \\
		$database/BFD \\
		$symlink ";

	##### Downloading AlphaFold2 parameters
	my $param_file = 'alphafold_params_2021-10-27.tar';
	my $param_url = 'https://storage.googleapis.com/alphafold/'."$param_file";
	my $param_dir = "$af_dbs/params";

	unless (-d $param_dir){
		mkdir ($param_dir, 0755) or die "Can't create $param_dir: $!\n";
	}

	aria($param_file, $param_url, $param_dir);
	untar("$param_dir/$param_file", $param_dir);

	##### Downloading MGnify
	my $mgy_file = 'mgy_clusters_2018_12.fa.gz';
	my $mgy_url = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/'."$mgy_file";

	my $mgy_folder = "$af_dbs/mgnify";
	unless (-d $mgy_folder) {
		mkdir ($mgy_folder, 0755) or die "Can't create $mgy_folder: $!\n";
	}

	aria($mgy_file, $mgy_url, $mgy_folder);
	unzip("$mgy_folder/$mgy_file");
	
	##### Downloading pdb70
	my $pdb70_file = 'pdb70_from_mmcif_200401.tar.gz';
	my $pdb70_url = 'http://wwwuser.gwdg.de/~compbiol/data/hhsuite/databases/hhsuite_dbs/old-releases/'."$pdb70_file";
	my $pdb70_dir = "$af_dbs/pdb70";

	unless (-d $pdb70_dir){
		mkdir ($pdb70_dir, 0755) or die "Can't create $pdb70_dir: $!\n";
	}

	aria($pdb70_file, $pdb70_url, $pdb70_dir);
	untar("$pdb70_dir/$pdb70_file", $pdb70_dir);

	##### Downloading pdb_mmcif with Perl
	# reimplementation of Alphafold download_pdb_mmcif.sh

	my $mmcif_root_dir = "$af_dbs/pdb_mmcif";
	my $mmcif_raw_dir = "$mmcif_root_dir/raw";
	my $mmcif_file_dir = "$mmcif_root_dir/mmcif_files";

	unless (-d $mmcif_root_dir){ mkdir ($mmcif_root_dir, 0755) or die "Can't create $mmcif_root_dir: $!\n"; }
	unless (-d $mmcif_raw_dir){ mkdir ($mmcif_raw_dir, 0755) or die "Can't create $mmcif_raw_dir: $!\n"; }
	unless (-d $mmcif_file_dir){ mkdir ($mmcif_file_dir, 0755) or die "Can't create $mmcif_file_dir: $!\n"; }

	print "Downloading mmCIF files from RCSB PDB with Rsync\n";
	system "rsync \\
		--recursive \\
		--links \\
		--perms \\
		--times \\
		--compress \\
		--info=progress2 \\
		--delete \\
		--port=33444 \\
		rsync.rcsb.org::ftp_data/structures/divided/mmCIF/ \\
		$mmcif_raw_dir";

	print "Unzipping all mmCIF files...\n";
	system "find \\
		$mmcif_raw_dir \\
		-type f \\
		-iname *.gz \\
		-exec ".'gunzip {} +';

	# Delete empty directories.
	print "Flattening all mmCIF files...\n";
	system "find $mmcif_raw_dir -type d -empty -delete";
	system "for subdir in $mmcif_raw_dir/*; do \\
		mv \${subdir}/*.cif $mmcif_file_dir; \\
		done";

	# Delete empty download directory structure.
	system "find $mmcif_raw_dir -type d -empty -delete";

	system "aria2c \\
		-x$aria_connections \\
		ftp://ftp.wwpdb.org/pub/pdb/data/status/obsolete.dat \\
		--dir=$mmcif_root_dir";

	##### Downloading pdb_seqres; for AlphaFold-Multimer
	my $seqres_file = 'pdb_seqres.txt';
	my $seqres_url = 'ftp://ftp.wwpdb.org/pub/pdb/derived_data/'."$seqres_file";
	my $seqres_dir = "$af_dbs/pdb_seqres";
	
	unless (-d $seqres_dir) {
		mkdir ($seqres_dir , 0755) or die "Can't create $seqres_dir: $!\n";
	}

	aria($seqres_file, $seqres_url, $seqres_dir);
	
	##### Downloading small_bfd
	my $smallbfd_file = 'bfd-first_non_consensus_sequences.fasta.gz';
	my $smallbfd_url = 'https://storage.googleapis.com/alphafold-databases/reduced_dbs/'."$smallbfd_file";
	my $small_bfd_dir = "$af_dbs/small_bfd";
	
	unless (-d $small_bfd_dir) {
		mkdir ($small_bfd_dir , 0755) or die "Can't create $small_bfd_dir: $!\n";
	}

	aria($smallbfd_file, $smallbfd_url, $small_bfd_dir);
	unzip("$small_bfd_dir/$smallbfd_file");

	##### Downloading UniClust30
	my $uni30_file = 'uniclust30_2018_08_hhsuite.tar.gz';
	my $uni30_url = 'https://storage.googleapis.com/alphafold-databases/casp14_versions/'."$uni30_file";

	my $uni30_dir = "$af_dbs/uniclust30";
	unless (-d $uni30_dir) {
		mkdir ($uni30_dir , 0755) or die "Can't create $uni30_dir: $!\n";
	}

	aria($uni30_file, $uni30_url, $uni30_dir);
	untar("$uni30_dir/$uni30_file", $uni30_dir);

	##### Downloading UniProt; for AlphaFold-Multimer
	my $sprot_file = 'uniprot_sprot.fasta.gz';
	my $trembl_file = 'uniprot_trembl.fasta.gz';
	my $sprot_url = 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/'."$sprot_file";
	my $trembl_url = 'ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/'."$trembl_file";

	my $uniprot_dir = "$af_dbs/uniprot";
	unless (-d $uniprot_dir) {
		mkdir ($uniprot_dir , 0755) or die "Can't create $uniprot_dir: $!\n";
	}

	aria($sprot_file, $sprot_url, $uniprot_dir);
	aria($trembl_file, $trembl_url, $uniprot_dir);
	
	unzip("$uniprot_dir/$sprot_file");
	unzip("$uniprot_dir/$trembl_file");

	$sprot_file =~ s/.gz$//;
	$trembl_file =~ s/.gz$//;

	system "cat $uniprot_dir/$sprot_file >> $uniprot_dir/$trembl_file";
	system "mv $uniprot_dir/$trembl_file $uniprot_dir/uniprot.fasta";
	system "rm $uniprot_dir/$sprot_file";

	##### Downloading UniRef90
	my $uni90_file = 'uniref90.fasta.gz';
	my $uni90_url = 'ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/'."$uni90_file";

	my $uni90_dir = "$af_dbs/uniref90";
	unless (-d $uni90_dir) {
		mkdir ($uni90_dir , 0755) or die "Can't create $uni90_dir: $!\n";
	}

	aria($uni90_file, $uni90_url, $uni90_dir);
	unzip("$uni90_dir/$uni90_file");

}
# End of AlphaFold databases
################################################

################################################
# RoseTTAFold databases
if ($rosettafold or $all_databases){

	my $rf_dbs = "$database/ROSETTAFOLD";
	unless (-d $rf_dbs){ mkdir ($rf_dbs, 0755) or die "Can't create $rf_dbs: $!\n"; }

	##### Creating symlink to bfd inside ROSETTAFOLD
	my $symlink = "$rf_dbs/bfd";
	if (-l $symlink){ system "unlink $symlink";	}

	system "ln -s \\
		$database/BFD \\
		$symlink";
	
	##### Downloading Weights
	my $w_file = 'weights.tar.gz';
	my $w_url = 'https://files.ipd.uw.edu/pub/RoseTTAFold/'."$w_file";

	aria($w_file, $w_url, $rf_dbs);
	untar("$rf_dbs/$w_file", $rf_dbs);

	##### Downloading UniRef30
	my $uniref30_file = 'UniRef30_2020_06_hhsuite.tar.gz';
	my $uniref30_url = 'http://wwwuser.gwdg.de/~compbiol/uniclust/2020_06/'."$uniref30_file";
	my $uniref30_dir = "$rf_dbs/UniRef30_2020_06";

	unless (-d "$uniref30_dir"){
		mkdir ($uniref30_dir, 0755) or die "Can't create $uniref30_dir: $!\n";
	}

	aria($uniref30_file, $uniref30_url, $uniref30_dir);
	untar("$uniref30_dir/$uniref30_file", $uniref30_dir);

	##### Downloading structure templates
	my $template_file = 'pdb100_2021Mar03.tar.gz';
	my $template_url = 'https://files.ipd.uw.edu/pub/RoseTTAFold/'."$template_file";

	aria($template_file, $template_url, $rf_dbs);
	untar("$rf_dbs/$template_file", $rf_dbs);

}
# End of RoseTTAFold databases
################################################

################################################
# RaptorX databases
if ($raptorx or $all_databases){

	my $raptorx_file = 'raptorx_databases.tar.gz';
	my $raptorx_url = 'http://bioinformatics.one/3DFI/raptorx/'."$raptorx_file";

	aria($raptorx_file, $raptorx_url, $database);
	untar("$database/$raptorx_file", $database);

}
# End of RaptorX databases
################################################

################################################
# Subroutine(s)

sub aria { ## using aria2 to download files
	
	my ($file, $url, $outdir) = @_;
	my $aria = "$outdir/$file".'.aria2';
	my $ltime = localtime;

	## Checking for partial aria2 download => resume
	if (-f "$aria"){
		print "\n# $ltime: Resuming download of $file with aria2\n";
		system "aria2c \\
			-x$aria_connections \\
			$url \\
			--dir=$outdir";
	}
	## Checking if file exists without an .aria2 progess file => skip download
	elsif (-f "$outdir/$file"){
		print "\n# $ltime:\n";
		print "Found $file in $outdir but no .aria2 download progress file\n";
		print "Assuming that the aria2 download of $file is complete\n";
		print "Skipping downloading and moving to next step...\n";
	}
	## Else => download
	else {
		print "\n# $ltime: Downloading $file with aria2\n";
		system "aria2c \\
			-x$aria_connections \\
			$url \\
			--dir=$outdir";	
	}

}

sub untar { ## For gzipped tar archives

	my ($file, $outdir) = @_;
	my $ltime = localtime;

	## File size
	my $disk_usage = `du -sh $file`;
	my ($size) = $disk_usage =~ /^(\S+)/; 
	my $step = '.50000';

	unless ($no_unpack){

		print "\n# $ltime: Unpacking $file\n";
		print "\nFile size = $size\n";

		## Tar archive, not gzipped
		if ($file =~ /\.tar$/){
			system "tar \\
				--extract \\
				--checkpoint=$step \\
				--totals \\
				--file=$file \\
				--directory=$outdir";
		}
		## Tar archive, gzipped
		else {
			if ($decompression_tool eq 'pigz'){
				system "pigz \\
					-dc $file | \\
					tar \\
					--extract \\
					--checkpoint=$step \\
					--totals \\
					--directory=$outdir";
			}
			else {
				system "tar \\
					--extract \\
					--checkpoint=$step \\
					--totals \\
					--file=$file \\
					--directory=$outdir";
			}
		}

		## Making sure that database files are readable by everyone
		system "chmod -R +r $outdir";

		# Delete file if flag is on
		if ($delete){
			print "\nDeleting $file\n\n";
			system "rm $file";
		}

	}

}

sub unzip { ## For gzipped files...

	my ($file) = @_;
	my $ltime = localtime;

	## File size
	my $disk_usage = `du -sh $file`;
	my ($size) = $disk_usage =~ /^(\S+)/; 

	unless ($no_unpack){

		print "\n# $ltime: Unpacking $file with $decompression_tool\n";
		print "\nFile size = $size\n";

		if ($delete){ system "$decompression_tool $file"; }
		else { system "$decompression_tool -k $file"; }
		
	}
}