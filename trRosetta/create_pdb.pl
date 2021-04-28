#!/usr/bin/perl
## Pombert Lab 2020
my $version = '0.2a';
my $name = 'create_pdb.pl';
my $updated = '2021-04-22';

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
		  -n NPZ/*.npz \\
		  -o PDB/ \\
		  -f FASTA_OL/ \\
		  -t /media/Data_3/opt/trRosetta/pdb/trRosetta.py

OPTIONS:
-c (--cpu)	Number of cpu threads to use [Default: 10] ## i.e. runs n processes in parallel
-m (--memory)	Memory available (in Gb) to threads [Default: 16] 
-n (--npz)	.npz files generated by hhblits
-o (--output)	Output folder [Default: ./]
-f (--fasta)	Folder containing the oneliner fasta files
-t (--trosetta)	Path to trRosetta.py from trRosetta
-p (--python)	Preferred Python interpreter [Default: python]
OPTIONS
die "\n$USAGE\n" unless @ARGV;

my @commands = @ARGV;

## Defining options
my @npz;
my $out = './';
my $trosetta;
my $fasta;
my $threads = 10;
my $python = 'python';
my $memory = 16;
GetOptions(
	'n|npz=s@{1,}' => \@npz,
	'o|output=s' => \$out,
	't|trosetta=s' => \$trosetta,
	'f|fasta=s' => \$fasta,
	'c|cpu=i' => \$threads,
	'p|python=s' => \$python,
	'm|memory=i' => \$memory
);

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


my $max_file_memory :shared  = 0.0078125*($memory*(10**9));
my $max_file_memory_p = $max_file_memory/(10**6);
my $file_memory :shared = $max_file_memory;
my @large_files :shared;
my $total_files :shared = scalar(@files);
my %running_processes :shared;
my $running_threads :shared = 0;
my $folding_threads:shared = 0;
my @output_pdb;
my $buffer = "-" x 100;

## Create threads that run the exe subroutine
for my $thread (@threads){
	$thread = threads -> create(\&exe);
}

## Run until threads are done
for my $thread (@threads){
	$thread -> join();
}

$total_files = scalar(@large_files);

while (my $npz = shift(@large_files)){

	my ($name, $dir) = fileparse($npz);
	my ($prefix, $evalue) = $name =~ /^(\S+)\.(\S+)\.(\w+)$/;

	my $buffer = "-" x 100;

	system "$python \\
		$trosetta \\
		$npz \\
		$fasta/$prefix.fasta \\
		$out/$prefix.$evalue.pdb"
	;

	system "clear";
	my $remaining = "." x (int((scalar(@large_files)/$total_files)*100));
	my $progress = "|" x (100-int((scalar(@large_files)/$total_files)*100));
	my $status = "[".$progress.$remaining."]";
	print("Folding Proteins with Single-threading\n");
	print("\n\t$status\t".($total_files-scalar(@large_files))."/$total_files\n");

	unless(-e "$out/$prefix.$evalue.pdb"){
		print LOG "$out/$prefix.$evalue.pdb";
		print LOG "\n$buffer\nMain thread has failed to fold file $name\n$buffer\n\n";
	}

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

sub exe{

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

		unless (scalar(@files) > 0){
			last PROCESS;
		}
		else{
			lock(@files);
			$npz = shift(@files);
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
		}

		my ($name, $dir) = fileparse($npz);
		my ($prefix, $evalue) = $name =~ /^(\S+)\.(\S+)\.(\w+)$/;

		my $buffer = "-" x 100;

		if(-e "$out/$prefix.$evalue.pdb"){
			print LOG "$out/$prefix.$evalue.pdb already exists, moving to next npz...\n";
			next;
		}

		## Check if file size is greater than maximum
		if ((-s $npz) < $max_file_memory){
			## Check if file can be opened given the alloted resources

			for my $i (1){
				## Remove file memory from memory available
				lock($file_memory);
				$file_memory -= -s $npz;
			}

			if (0 < $file_memory){
				## If file can be run, run it

				if($0){
					lock(%running_processes);
					lock($folding_threads);
					$running_processes{$id} = "Thread $id: Folding $npz.\n";
					$folding_threads ++;
				}

				system "$python \\
					$trosetta \\
					$npz \\
					$fasta/$prefix.fasta \\
					$out/$prefix.$evalue.pdb"
				;

				unless(-e "$out/$prefix.$evalue.pdb"){
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: Failed to fold $npz. Placing back in the queue.\n";
					push(@files,$npz);
				}
				else{
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: Folding on $npz has completed.\n";
					print LOG "\n$buffer\nThread $id has completed on file $name\n$buffer\n\n";
				}

				if($0){
					lock($folding_threads);
					$folding_threads--;
				}

			}
			else{
				## If file can't be run, put it at the back of the line and try again later
				if((-s $npz) > .5*$max_file_memory){
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: $npz is too large for Multi-threading. Sending to Single-threaded queue.\n";
					push(@large_files,$npz);
				}
				else{
					lock(%running_processes);
					$running_processes{$id} = "Thread $id: Not enough memory clearance to fold $npz. Placing back in the queue.\n";
					push(@files,$npz);
				}
			}

			for my $i (1){
				## Add file memory to total memory available
				lock($file_memory);
				$file_memory += -s $npz;
			}

		}
		else{
			## If file is large, need to run it one by one
			## Add large file to $large_files
			lock($total_files);
			lock(%running_processes);
			$total_files -= 1;
			$running_processes{$id} = "Thread $id: $npz is too large for Multi-threading. Sending to Single-threaded queue.\n";
			push(@large_files,$npz);

		}
		sleep(15);
		
	}
	lock($running_threads);
	lock(%running_processes);
	$running_threads--;
	$running_processes{$id} = "Thread $id: No more jobs to run.\n";
	threads -> exit();

}
