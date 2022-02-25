#!/usr/bin/perl
## Pombert Lab 2022

my $name = "run_MICAN_on_GESAMT_results.pl";
my $version = "0.1a";
my $updated = "2022-02-25";

use strict;
use warnings;
use PerlIO::gzip;
use File::Basename;
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);

my $usage = <<"EXIT";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	The purpose of this script is to to calculate the Template Model (TM) score by running the MICAN sequence alignment tool,
		an indicator of the strength a predicted protein model shares with the expiremental model it is attempting to represent.

USAGE

OPTION
-t (--tdfi)		3DFI output folder
-r (--rcsb)		Path to RCSB PDB structures
-o (--outdir)		Output directory (Default: MICAN_RESULTS)
EXIT

die("\n$usage\n") unless(@ARGV);

my ($script,$pipeline_dir) = fileparse($0);
$pipeline_dir =~ s/Homology_search/Misc_tools/;

my %Folds = ("ALPHAFOLD" => "ALPHAFOLD_3D_Parsed",
			 "RAPTORX" => "RAPTORX_3D/PDB"
);

my $tdfi;
my @rcsb;
my $outdir = "MICAN_RESULTS";

GetOptions(
	'-t|--tdif=s{1}' => \$tdfi,
	'-r|--rcsb=s@{1,}' => \@rcsb,
	'-o|--outdir=s' => \$outdir,
);

my $datestring = localtime();
open LOG, ">", "$outdir/MICAN.log";
print LOG ("$0 \\\n-t $tdfi \\\n-r @rcsb \\\n-o $outdir\n\n");
print LOG ("Started on $datestring\n");

my $rcsb_temp_dir = "$outdir/tmp_rcsb";

unless(-d $outdir){
	make_path($rcsb_temp_dir,{mode=>0755});
}

open IN, "<", "$tdfi/Homology/GESAMT/All_GESAMT_matches_per_protein.tsv" or die "Unable to open file $tdfi/Homology/GESAMT/All_GESAMT_matches_per_protein.tsv: $!\n";
my $total_alignments;
while(my $line = <IN>){
	unless(($line =~ /^###/) || ($line eq "")){
		$total_alignments++;
	}
}
close IN;

open IN, "<", "$tdfi/Homology/GESAMT/All_GESAMT_matches_per_protein.tsv" or die "Unable to open file $tdfi/Homology/GESAMT/All_GESAMT_matches_per_protein.tsv: $!\n";
open RAW, ">", "$outdir/MICAN_raw.tsv";
print RAW ("### Query\tPredictor\tRCSB Code\tChain\tsTMscore\tTMscore\tDali_Z\tSPscore\tLength\tRMSD\tSeq_Id\n");

my $alignment_counter = 0;
while(my $line = <IN>){
	chomp($line);
	unless(($line =~ /^###/) || ($line eq "")){


		my ($query,$predictor,$rcsb_code,$chain,$qscore,$rmsd,$seq_id,$nAlign,$nRes,$rcsb_file,$annotation) = split("\t",$line);
		my ($rcsb_sub_folder) = lc($rcsb_code) =~ /\w(\w{2})\w/;

		## Checking in current and obsolete RCSB PDB folders
		my $rcsb_file_location;
		for my $rcsb_dir (@rcsb){
			if (-f "$rcsb_dir/$rcsb_sub_folder/$rcsb_file"){
				$rcsb_file_location = "$rcsb_dir/$rcsb_sub_folder/$rcsb_file";
				last;
			}
		}

		if($rcsb_file_location){
			system "clear";
			print("\n\tAligning $query to $rcsb_code\n");
			my $remaining = "." x (int((($total_alignments-$alignment_counter)/$total_alignments)*100));
			my $progress = "|" x (100-int((($total_alignments-$alignment_counter)/$total_alignments)*100));
			my $status = "[".$progress.$remaining."]";
			print "\n\t$status\t".($alignment_counter)."/$total_alignments\n\t";

			system "cp $rcsb_file_location $rcsb_temp_dir/$rcsb_file\n";

			# split_PDB.pl \
			#   -p files.pdb \
			#   -o output_folder \
			#   -e pdb

			# -p (--pdb)	PDB input file (supports gzipped files)
			# -o (--output)	Output directory. If blank, will create one folder per PDB file based on file prefix
			# -e (--ext)	Desired file extension [Default: pdb]

			if(-f "$pipeline_dir/split_PDB.pl"){
				system "$pipeline_dir/split_PDB.pl \\
						-p $rcsb_temp_dir/$rcsb_file \\
						-o $rcsb_temp_dir/tmp/ \\
						-e pdb
				";
			}
			else{
				print STDERR "[E] Cannot find $pipeline_dir/split_PDB.pl\n";
			}

			my $temp_file = "$rcsb_temp_dir/tmp/pdb".lc($rcsb_code)."/pdb".lc($rcsb_code)."_$chain.pdb";
			my $predicted_file_location = "$tdfi/Folding/".$Folds{$predictor}."/$query.pdb";

			my $mican_result = `mican -s $predicted_file_location $temp_file -n 1`;
			$alignment_counter++;
			
			system "rm -rf $rcsb_temp_dir/*";

			my @data = split("\n",$mican_result);

			my $grab;
			my $rank;
			my $sTMscore;
			my $TMscore;
			my $Dali_Z;
			my $SPscore;
			my $Length;
			my $RMSD;
			my $Seq_Id;
			foreach my $line (@data){
				chomp($line);
				if($line =~ /Rank\s+sTMscore/){
					$grab = 1;
				}
				if(($grab) && ($line =~ /^\s+(1.*)/)){
					undef($grab);
					($rank,$sTMscore,$TMscore,$Dali_Z,$SPscore,$Length,$RMSD,$Seq_Id) = split(/\s+/,$1);
					print RAW ("$query\t$predictor\t$rcsb_code\t$chain\t$sTMscore\t$TMscore\t$Dali_Z\t$SPscore\t$Length\t$RMSD\t$Seq_Id\n");
				}
			}
		}
		else{
			print STDERR "Unable to find $rcsb_file\n";
		}

	}
	elsif($line =~ /^### (\w+)/){
		print RAW ("### $1\n");
	}
	else{
		print RAW ("\n");
	}
}

print LOG ("$alignment_counter proteins aligned\n");
$datestring = localtime();
print LOG ("Completed on $datestring\n");

close IN;
close RAW;
close LOG;
