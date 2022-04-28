#!/usr/bin/perl
## Pombert Lab 2022

my $name = "run_MICAN_on_homology_results.pl";
my $version = "0.2a";
my $updated = "2022-04-27";

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
SYNOPSIS	Calculates template model (TM) and RMSD scores with MICAN on structural
		matches identified with foldseek or GESAMT

USAGE

OPTION
-t (--tdfi)		3DFI output folder
-r (--rcsb)		Path to RCSB PDB structures
-a (--align)	3D alignment tool: folseek or gesamt [Default: gesamt]
-o (--outdir)		Output directory (Default: MICAN_RESULTS)
EXIT

die "\n$usage\n" unless @ARGV;

my ($script,$pipeline_dir) = fileparse($0);
$pipeline_dir =~ s/Homology_search/Misc_tools/;

my %Folds = ("ALPHAFOLD" => "ALPHAFOLD_3D_Parsed",
			 "RAPTORX" => "RAPTORX_3D/PDB"
);

my $tdfi;
my @rcsb;
my $aligner = 'gesamt';
my $outdir = "MICAN_RESULTS";

GetOptions(
	't|tdif=s{1}' => \$tdfi,
	'r|rcsb=s@{1,}' => \@rcsb,
	'a|align=s' => \$aligner,
	'o|outdir=s' => \$outdir,
);

my $rcsb_temp_dir = "$outdir/tmp_rcsb";

unless(-d $outdir){
	make_path($rcsb_temp_dir,{mode=>0755});
}

my %resume;
if(-f "$outdir/MICAN_raw.tsv"){
	open RAW, "<", "$outdir/MICAN_raw.tsv";
	while (my $line = <RAW>){
		chomp($line);
		if($line =~ /\w+/){
			my ($locus,$predictor,$rcsb_code,$rcsb_chain) = split("\t",$line);
			$resume{$locus}{$predictor}{$rcsb_code}{$rcsb_chain} = $line;
		}
	}
}

my $datestring = localtime();
open LOG, ">", "$outdir/MICAN.log" or die "Unable to create file $outdir/MICAN.log: $!\n";
print LOG "$0 \\\n-t $tdfi \\\n-r @rcsb \\\n-o $outdir\n\n";
print LOG "Started on $datestring\n";

my $ualigner = uc($aligner);
my $tsv_name = "$tdfi/Homology/$ualigner/All_${ualigner}_matches_per_protein.tsv";
open IN, "<", $tsv_name or die "Unable to open $tsv_name: $!\n";
my $total_alignments;
while (my $line = <IN>){
	unless (($line =~ /^###/) || ($line eq "")){
		$total_alignments++;
	}
}
close IN;

open IN, "<", $tsv_name or die "Unable to open $tsv_name: $!\n";
open RAW, ">", "$outdir/MICAN_raw.tsv";
print RAW "### Query\tPredictor\tRCSB Code\tChain\tsTMscore\tTMscore\tDali_Z\tSPscore\tLength\tRMSD\tSeq_Id\n";

my $alignment_counter = 0;
while (my $line = <IN>){

	chomp($line);

	unless (($line =~ /^###/) || ($line eq "")){

		my $query;
		my $predictor;
		my $rcsb_code;
		my $chain;
		my $rcsb_file;
		my $rcsb_code_and_chain;

		my @columns = split("\t",$line);
		$query = $columns[0];
		$predictor = $columns[1];
		if ($aligner eq 'gesamt'){
			$rcsb_code = $columns[2];
			$chain  = $columns[3];
			$rcsb_file = $columns[9];
		}
		elsif ($aligner eq 'foldseek'){
			$rcsb_code_and_chain = $columns[2];
			($rcsb_file) = $rcsb_code_and_chain =~ /^(pdb\w{4}.ent.gz)/;
			if ($rcsb_code_and_chain =~ /^pdb(\w{4}).ent.gz_(\S+)$/){
				$rcsb_code = $1;
				$chain = $2;
			}
			elsif ($rcsb_code_and_chain =~ /^pdb(\w{4}).ent.gz$/){
				$rcsb_code = $1;
				$chain = 'A';
			}
		}
		my ($rcsb_sub_folder) = lc($rcsb_code) =~ /\w(\w{2})\w/;

		## Checking to see if this calculation has been performed previously
		if ($resume{$query}{$predictor}{$rcsb_code}{$chain}){
			print($resume{$query}{$predictor}{$rcsb_code}{$chain}."\n");
			next;
		}

		## Checking in current and obsolete RCSB PDB folders
		my $rcsb_file_location;
		for my $rcsb_dir (@rcsb){
			if (-f "$rcsb_dir/$rcsb_sub_folder/$rcsb_file"){
				$rcsb_file_location = "$rcsb_dir/$rcsb_sub_folder/$rcsb_file";
				last;
			}
		}

		if ($rcsb_file_location){
			system "clear";
			print "\n\tAligning $query to $rcsb_code\n";
			my $remaining = "." x (int((($total_alignments-$alignment_counter)/$total_alignments)*100));
			my $progress = "|" x (100-int((($total_alignments-$alignment_counter)/$total_alignments)*100));
			my $status = "[".$progress.$remaining."]";
			print "\n\t$status\t".($alignment_counter)."/$total_alignments\n\t";

			system "cp $rcsb_file_location $rcsb_temp_dir/$rcsb_file\n";

			if (-f "$pipeline_dir/split_PDB.pl"){
				system "$pipeline_dir/split_PDB.pl \\
						-p $rcsb_temp_dir/$rcsb_file \\
						-o $rcsb_temp_dir/tmp/ \\
						-e pdb
				";
			}
			else {
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
				if ($line =~ /Rank\s+sTMscore/){
					$grab = 1;
				}
				if (($grab) && ($line =~ /^\s+(1.*)/)){
					undef($grab);
					($rank,$sTMscore,$TMscore,$Dali_Z,$SPscore,$Length,$RMSD,$Seq_Id) = split(/\s+/,$1);
					print RAW "$query\t$predictor\t$rcsb_code\t$chain\t$sTMscore\t$TMscore\t$Dali_Z\t$SPscore\t$Length\t$RMSD\t$Seq_Id\n";
				}
			}
		}
		else {
			print STDERR "Unable to find $rcsb_file\n";
		}

	}
	elsif ($line =~ /^### (\w+)/){
		print RAW "### $1\n";
	}
	else{
		print RAW "\n";
	}
}

print LOG "$alignment_counter proteins aligned\n";
$datestring = localtime();
print LOG "Completed on $datestring\n";

close IN;
close RAW;
close LOG;
