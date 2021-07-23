#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.3';
my $name = 'create_pdb.pl';
my $updated = '2021-07-23';

use strict; use warnings; use Getopt::Long qw(GetOptions); use File::Basename; use threads; use threads::shared;

## Usage definition
my $USAGE = <<"OPTIONS";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Creates .pdb files with trRosetta from .npz files
REQUIREMENTS	trRosetta - https://github.com/gjoni/trRosetta

COMMAND		${name} \\
		  -c 10 \\
		  -n NPZ/ \\
		  -o PDB/ \\
		  -f FASTA_OL/ \\
		  -t /opt/trRosetta

NOTE:	The -t option is not required if the environment variable TRROSETTA_HOME is set, e.g.:
	export TRROSETTA_HOME=/opt/trRosetta

OPTIONS:
-c (--cpu)		Number of cpu threads to use [Default: 10] ## i.e. runs n processes in parallel
-m (--memory)		Memory available (in Gb) to threads [Default: 16] 
-n (--npz)		Folder containing .npz files
-o (--output)		Output folder [Default: ./]
-f (--fasta)		Folder containing the oneliner fasta files
-t (--trrosetta)	trRosetta installation directory (TRROSETTA_HOME)
-p (--python)		Preferred Python interpreter [Default: python]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

my @commands = @ARGV;

## Defining options
my $npz_dir;
my $out = './';
my $trrosetta_home;
my $fasta;
my $threads = 10;
my $python = 'python';
my $memory = 16;
GetOptions(
	'n|npz=s' => \$npz_dir,
	'o|output=s' => \$out,
	't|trrosetta=s' => \$trrosetta_home,
	'f|fasta=s' => \$fasta,
	'c|cpu=i' => \$threads,
	'p|python=s' => \$python,
	'm|memory=i' => \$memory
);

### Checking for tRosetta installation; environment variables in Perl are loaded in %ENV
# Checking installation folder
if (!defined $trrosetta_home){
	if (exists $ENV{'TRROSETTA_HOME'}){ $trrosetta_home = $ENV{'TRROSETTA_HOME'}; }
	else {
		print "WARNING: The trRosetta installation directory is not set as an environment variable (\$TRROSETTA_HOME) and the -r option was not entered.\n";
		print "Please check if trRosetta was installed properly\n\n";
		exit;
	}
}
elsif (defined $trrosetta_home){
	unless (-d $trrosetta_home){ die "WARNING: Can't find trRosetta installation folder: $trrosetta_home. Please check command line\n\n"; }
}

## Load npz files into an array
my @npz;
opendir(DIR,$npz_dir) or die("Can't open $npz_dir: $!\n");
while (my $file = readdir(DIR)){
	if ($file =~ /^(\w+)\.npz/){
		push(@npz,"$npz_dir/$file");
	}
}

## Checking output folder
unless (-d $out){
	mkdir ($out,0755) or die "Can't create folder $out: $!\n";
}

## Creating log file
open LOG, ">", "$out/create_pdb.log" or die "Can't create create_pdb.log in $out: $!\n";
my $time = `date`;
print LOG "$name version $version started on $time\n";
print LOG "COMMANDS:\n";
print LOG "$name @commands\n";

## Initialize # of threads specified
my @threads = initThreads();

## Copying the array into a shared list for multithreading (use threads::shared;)
my @files :shared = @npz;

## Setting the maximum shared file size to prevent RAM overloading
my $max_file_memory :shared  = 0.0078125*($memory*(10**9));
## Printable version of shared file size
my $max_file_memory_p = $max_file_memory/(10**6);
## Setup shared file size tracker
my $file_memory :shared = $max_file_memory;
## Create large file array for single threading
my @large_files :shared;
## Total amount of files
my $total_files :shared = scalar(@files);
## Initialize running process printout
my %running_processes :shared;
## Running threads counter
my $running_threads :shared = 0;
## Folding threads counter
my $folding_threads :shared = 0;
## Threads completed
my $completed :shared = 0;
my $start :shared;
my @output_pdb;
## Printout buffer
my $buffer = "-" x 100;

## Create threads that run the exe subroutine
for my $thread (@threads){
	$thread = threads -> create(\&mt_exe);
}
my $print_thread = threads -> create(\&mt_po);

## Run until threads are done
for my $thread (@threads){
	$thread -> join();
}

$total_files = scalar(@large_files);

$completed = 0;

if (@large_files){
	my $thr1 = threads -> create(\&st_exe);
	my $thr2 = threads -> create(\&st_po);
	$thr1 -> join();
	$thr2 -> join();
}

## End time
my $end = `date`;
print LOG "$name ended on $end\n";

## Subroutines
sub initThreads{ 
	# An array to place our threads in
	my @initThreads;
	for (my $i = 1; $i <= $threads; $i++){ push(@initThreads,$i); }
	return @initThreads;
}


### Multi-thread folding function
sub mt_exe{

	## Get the thread id. Allows each thread to be identified.
	my $t_id = threads->tid();
	my $id = sprintf("%02d",$t_id);
	if($0){
		lock($running_threads);
		$running_threads++;
	}

	## While files remain to be folded

	PROCESS: while (0==0){

		my $npz;

		## If the number of files is less than the number of threads, release non-utilized threads, if not, grab next
		## npz file
		unless (scalar(@files) > 0){
			last PROCESS;
		}
		else{
			lock(@files);
			$npz = shift(@files);
		}

		my ($name, $dir) = fileparse($npz);
		my ($prefix, $evalue) = $name =~ /^(\S+)\.(\S+)\.(\w+)$/;

		if (-e "$out/$prefix.$evalue.pdb"){
			print LOG "$out/$prefix.$evalue.pdb already exists, moving to next npz...\n";
			next;
		}

		## Check if file size is greater than maximum
		if ((-s $npz) < $max_file_memory){
			## Check if file can be opened given the alloted resources

			## Update available file memory
			if ($0){
				lock($file_memory);
				$file_memory -= -s $npz;
			}

			## If memory is available, fold the npz
			if (0 < $file_memory){
				## Update process printout
				if ($0){
					lock(%running_processes);
					lock($folding_threads);
					$running_processes{$id} = "Thread $id: Folding $name started on ".localtime()."\n";
					$folding_threads ++;
				}
				## Get starttime, run process, and get stop time
				my $starttime = `date`;
				system "$python 2>trRosetta.ERROR.log \\
					$trrosetta_home/pdb/trRosetta.py \\
					$npz \\
					$fasta/$prefix.fasta \\
					$out/$prefix.$evalue.pdb"
				;
				my $endtime = `date`;

				## If the file did not fold, push it back into the queue to try again
				unless (-e "$out/$prefix.$evalue.pdb"){
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: Failed to fold $name. Placing back in the queue on ".localtime()."\n";
					push(@files,$npz);
				}
				else {
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: Folding on $name has completed.\n";
					print LOG "\n$buffer\nFile $name:\nStarted $starttime\nCompleted $endtime\n$buffer\n\n";
				}

				if ($0){
					lock($folding_threads);
					$folding_threads--;
				}

			}
			else{
				## If the file is greater than 50% of available memory, place it into the single file queue
				if ((-s $npz) > .5*$max_file_memory){
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: $name is too large for Multi-threading. Sendt to Single-threaded queue on ".localtime()."\n";
					push(@large_files,$npz);
				}
				else {
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: Not enough memory clearance to fold $name. Placed back in the queue on ".localtime()."\n";
					push(@files,$npz);
				}
			}

			if ($0){
				lock($file_memory);
				$file_memory += -s $npz;
			}
		}
		else {
			## If file is large, need to run it one by one
			## Add large file to $large_files
			lock($total_files);
			lock(%running_processes);
			$total_files -= 1;
			$running_processes{$id} = "Thread $id: $name is too large for Multi-threading. Sent to Single-threaded queue on ".localtime()."\n";
			push(@large_files,$npz);

		}
		sleep(5);
	}
	lock($running_threads);
	lock(%running_processes);
	lock($completed);
	$running_threads--;
	$running_processes{$id} = "Thread $id: No more jobs to run. Exited on ".localtime()."\n";
	$completed++;
	threads -> exit();
}

### Multi-thread printout
sub mt_po{
	WHILE: while (0==0){

		if ($completed == $threads){
			last WHILE;
		}

		if ($0){
			lock(@files);
			lock(%running_processes);
			lock($running_threads);
			lock($file_memory);
			system "clear";
			my $remaining = "." x (int((scalar(@files)/$total_files)*100));
			my $progress = "|" x (100-int((scalar(@files)/$total_files)*100));
			my $status = "[".$progress.$remaining."]";
			print "\nFolding Proteins with Multi-threading\n";
			print "\n\t$status\t".($total_files-scalar(@files))."/$total_files";
			print "\n\n\tThreads Running:\t$running_threads/$threads\n";
			print "\tThreads Folding:\t$folding_threads/$threads\n";
			print "\tAvailable Memory:\t".sprintf("%.2f",($file_memory/1000000))."/".($max_file_memory/1000000)." Mb\n\n\n";
			print "Thread Status:\n$buffer\n";
			foreach my $key (sort(keys(%running_processes))){
				chomp($running_processes{$key});
				print("$running_processes{$key}\n");
			}
			print("\n\n");
			sleep(2);
		}
	}
}

### Single-thread folding
sub st_exe{
	while (my $npz = shift(@large_files)){

		my ($name, $dir) = fileparse($npz);
		my ($prefix, $evalue) = $name =~ /^(\S+)\.(\S+)\.(\w+)$/;

		my $buffer = "-" x 100;
		
		if ($0) {
			lock($start);
			$start = localtime();
		}

		my $starttime = `date`;
		system "$python 2>trRosetta.ERROR.log \\
			$trrosetta_home/pdb/trRosetta.py \\
			$npz \\
			$fasta/$prefix.fasta \\
			$out/$prefix.$evalue.pdb"
		;

		my $endtime = `date`;

		unless (-e "$out/$prefix.$evalue.pdb"){
			print LOG "$out/$prefix.$evalue.pdb";
			print LOG "\n$buffer\nMain thread has failed to fold file $name\n$buffer\n\n";
		}
		else {
			print LOG "\n$buffer\nFile $name:\nStarted $starttime\nCompleted $endtime\n$buffer\n\n";
		}
	}
	lock($completed);
	$completed = 1;
	threads -> exit();
}

### Single-thread printout
sub st_po{
	WHILE: while (0 == 0){

		if ($completed == 1){
			last WHILE;
		}

		system "clear";
		my $remaining = "." x (int((scalar(@large_files)/$total_files)*100));
		my $progress = "|" x (100-int((scalar(@large_files)/$total_files)*100));
		my $status = "[".$progress.$remaining."]";
		print("Folding Proteins with Single-threading started on $start\n");
		print("\n\t$status\t".($total_files-scalar(@large_files))."/$total_files\n");
		sleep(2);
	}
	threads -> exit();
}
