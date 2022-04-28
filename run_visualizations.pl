#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = "run_visualizations.pl";
my $version = "0.2.3";
my $updated = "2022-04-27";

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;

my $usage = << "EXIT";
NAME		${name}
VERSION		${version}
UPDATED		${updated}
SYNOPSIS	Visualize predicted protein structures and their aligned homologs
		with ChimeraX

USAGE	${name} \\
		-a gesamt \\
		-r Results_3DFI

OPTIONS
-a (--align)	3D alignment tool: gesamt or foldseek [Default: gesamt]
-r (--results)	Results directory specified in run_3DFI.pl
EXIT

die "\n$usage\n" unless @ARGV;

my $in_dir;
my $aligner = 'gesamt';
GetOptions(
	'r|results=s' => \$in_dir,
	'a|align=s' => \$aligner
);

########################################################################################################################
# Generating predicted structure database                                                                              #
########################################################################################################################

my $pred_struct_file = "$in_dir/Visualization/predicted_structures.log";
my %predicted_structures;
my %loci_tracker;
my $locus;
open PRED_LOCI, "<", $pred_struct_file or die("\n[E]  Unable to open $pred_struct_file: $!\n");
while (my $line = <PRED_LOCI>){
	chomp($line);
	my @data = split("/",$line);
	my ($model) = $data[-1] =~ /(\S+)\-/;
	unless($loci_tracker{$model}){
		$loci_tracker{$model} = 1;
	}
}

close PRED_LOCI;

########################################################################################################################
# Parsing results from GESAMT match file                                                                               #
########################################################################################################################

my $ualigner = uc($aligner);
my $result_file = "$in_dir/Homology/$ualigner/All_${ualigner}_matches_per_protein.tsv";
my $script = $0;
my ($file,$vis_dir) = fileparse($script);
$vis_dir .= "/Visualization/Helper_Scripts/";
my %color_scripts = ("ALPHAFOLD" => "$vis_dir/color_alphafold.py", "ROSETTAFOLD" => "$vis_dir/color_rosettafold.py");

open RESULTS, "<", $result_file or die("\n[E]  Unable to open $result_file: $!\n");

my %results;
my %predictors;
while (my $line = <RESULTS>){
	chomp($line);
	if ($line =~ /^### (\S+?);/){
		$locus = $1;
	}
	elsif ($line =~ /^\S/){
		my @data = split("\t",$line);
		push(@{$results{$locus}},\@data);
		$predictors{uc($data[1])} = 1;
	}
}
close RESULTS;

########################################################################################################################
# Displaying results                                                                                                   #
########################################################################################################################

system "clear";

## Keep track of the locus that we are currently working on so we can move forward and back in order
my $locus_counter = 0;
## Default into best view mode
my $best_only = 1;
## Default into matches only
my $matches_only = 1;

## By default set all predictors available to VIEWABLE
my %viewable_predictors;
foreach my $key (keys(%predictors)){
	$viewable_predictors{$key} = 1;
}

my @loci = sort(keys(%loci_tracker));
my $separater = "=" x 125;
my @status = ("best","only proteins with matches");
my $warning_statement;

## Loop until user quits the visualization script
WHILE: while(0==0){

	my $locus = $loci[$locus_counter];
	my %viewable_models;
	opendir(VIS,"$in_dir/Visualization");
	foreach my $obj (readdir(VIS)){
		unless ($obj =~ /^\./){
			if (-e "$in_dir/Visualization/$obj"){
				if ($viewable_predictors{$obj}){
					opendir(MOD,"$in_dir/Visualization/$obj");
					foreach my $mods (readdir(MOD)){
						unless ($mods =~ /^\./){
							if ($mods =~ /$locus/){
								opendir(PDB,"$in_dir/Visualization/$obj/$mods");
								foreach my $pdb (readdir(PDB)){
									if ($pdb =~ /\.pdb$/){
										$viewable_models{$obj}{$pdb} = "$in_dir/Visualization/$obj/$mods/$pdb";
									}
								}
							}
						}
					}
				}
			}
		}
	}

	my @match_info;

	if ($results{$locus}){
		@match_info = @{$results{$locus}};
	}
	elsif ($matches_only){
		$locus_counter++;
		if ($locus_counter > scalar(@loci) - 1){
			$locus_counter = 0;
		}
		next;
	}

	####################################################################################################################
	# Printout results                                                                                                 #
	####################################################################################################################

	if ($warning_statement){
		print "\n\t[W]  $warning_statement\n";
	}
	print "\n\t### $locus has ".scalar(@match_info)." matches. ### \n\n\t\t- Currently in $status[0] match mode \n\t\t- Viewing $status[1]\n\n";
	print "\t|$separater|\n";
	print "\t Selection   Score     Predicted Structure      PDB-File => Chain     Structural Homolog Description\n";
	print "\t|$separater|\n";
	my $printed_counter = 0;
	foreach my $match (@match_info){
		unless ($printed_counter > 4 && $best_only){
			my @match = @{$match};
			unless ($viewable_predictors{$match[1]}){
				next;
			}
			## Gathering data for result printout
			my ($model) = sprintf(" => Model %-3i",$match[0] =~ /\w+\-m(\d+)/);
			my $predictor = sprintf("%13s",$match[1]);

			my $match_id;
			my $match_chain;
			my $q_score;

			if ($aligner eq 'gesamt'){
				$match_id = sprintf("%11s",$match[2]);
				$match_chain = sprintf(" => %-10s",$match[3]);
				$q_score = sprintf("   %-6.3f",$match[4]);
			}
			elsif ($aligner eq 'foldseek'){
				if ($match[2] =~ /^pdb(\w{4}).ent.gz_(\S+)$/){
					$match_id = $1;
					$match_chain = $2;
				}
				elsif ($match[2] =~ /^pdb(\w{4}).ent.gz$/){
					$match_id = $1;
					$match_chain = 'A';
				}
				$match_id = sprintf("%11s",$match_id);
				$match_chain = sprintf(" => %-10s",$match_chain);
				$q_score = sprintf("   %-6.0f",$match[-2]);
			}

			my $title = sprintf("%-15s",$match[-1]);
			my $formated_counter = sprintf("  %3s",$printed_counter+1);
			print "\t $formated_counter    ";
			print $q_score;
			print $predictor;
			print $model;
			print $match_id;
			print $match_chain;
			print $title;
			print "\n";
			$printed_counter++;
		}
	}
	print "\t|$separater|\n";

	####################################################################################################################
	# Option printouts                                                                                                 #
	####################################################################################################################

	print "\n\n\tSelectable Options:\n\n";

	if ($printed_counter > 0){
		print "\t\t[1-$printed_counter] Open corresponding match file\n";
	}
	print "\t\t[M] To select predicted structure\n";

	## Standard display options
	# All
	if ($best_only){
		print "\n\t\t[A] Show ALL matches\n";
	}
	else {
		print "\n\t\t[B] Show BEST matches\n";
	}
	if ($matches_only){
		print "\t\t[C] Include predicted structures without matches\n";
	}
	else {
		print "\t\t[D] Skip proteins without matches\n";
	}
	# Best

	## Navigational options
	# Next
	print "\n\t\t[N] Proceed to the next locus\n";
	# Previous
	print "\t\t[P] Proceed to the previous locus\n";
	# Jump
	print "\t\t[J] Jump to a selected locus\n";

	## Predictor display options
	# Hide
	my $shown_predictors = 0;
	foreach my $val (values(%viewable_predictors)){
		if ($val){
			$shown_predictors++;
		}
	}
	if ($shown_predictors == scalar(keys(%viewable_predictors))){
		print "\n\t\t[H] Hide a selected predictor\n";
	}
	# Show
	elsif ($shown_predictors == 0){
		print "\n\t\t[S] Show a selected predictor\n";
	}
	# Hide/Show
	else {
		print "\n\t\t[H] Hide a selected predictor\n";
		print "\t\t[S] Show a selected predictor\n";
	}
	print "\n\t\t[X] Exit the visualization tool\n";

	####################################################################################################################
	# Option selection processing                                                                                      #
	####################################################################################################################

	print "\n\tSelection: ";
	chomp (my $selection = <STDIN>);
	$selection = uc($selection);
	undef $warning_statement;

	# Selected to view a CXS file
	if ($printed_counter > 0 && $selection =~ /(\d+)/ && $selection < $printed_counter - 1){
		my $selected_locus = $1 - 1;
		my @selected_data = @{$match_info[$selected_locus]};
		my ($model) = $selected_data[0] =~ /(\S+)/;
		my $predictor = $selected_data[1];
		my $match_id;
		my $match_chain;
		if ($aligner eq 'gesamt'){
			$match_id = lc($selected_data[2]);
			$match_chain = $selected_data[3];
		}
		elsif ($aligner eq 'foldseek'){
			if ($selected_data[2] =~ /^pdb(\w{4}).ent.gz_(\S+)$/){
					$match_id = $1;
					$match_chain = $2;
			}
			elsif ($selected_data[2] =~ /^pdb(\w{4}).ent.gz$/){
				$match_id = $1;
				$match_chain = 'A';
			}
		}
		my $outfile = "${predictor}/${model}/${model}_${match_id}_${match_chain}";
		print "\nFILE = $outfile\n";
		exit;
		system "chimerax 2>/dev/null $in_dir/Visualization/$outfile.cxs $vis_dir/restore_chimerax_session.py &";
	}
	# Selected to view a predicted PDB model
	elsif ($selection eq "M"){
		print "\n\n\t\tWhich of the following predictors would you like to see viewable structural predictions for?\n\n";
		foreach my $predictor (sort(keys(%viewable_models))){
			if ($viewable_models{$predictor}){
				print "\t\t\t$predictor\n";
			}
		}
		print "\n\t\tSelection: ";
		chomp (my $selected_predictor = <STDIN>);
		print "\n\n\t\t\tWhich of the following models would you like to visualize?\n\n";
		if ($viewable_models{$selected_predictor}){
			foreach my $models (sort(keys(%{$viewable_models{$selected_predictor}}))){
				print "\t\t\t\t$models\n";
			}
			print "\n\t\t\tSelection: ";
			chomp (my $selected_model = <STDIN>);
			my $selected_model_path = $viewable_models{$selected_predictor}{$selected_model};
			my $colored_script = $color_scripts{$selected_predictor};
			unless ($colored_script){ $colored_script = ""; }
			if (-f $selected_model_path){
				system "chimerax 2>/dev/null $selected_model_path $colored_script &";
			}
			else {
				$warning_statement = "'$selected_model' is not a valid model selection.";
			}
		}
	}

	# Selected to view all results
	elsif ($selection eq "A" && $best_only){
		$status[0] = "all";
		undef $best_only;
	}

	# Selected to view best results
	elsif ($selection eq "B" && !$best_only){
		$status[0] = "best";
		$best_only = 1;
	}

	# Selected to view all proteins
	elsif ($selection eq "C" && $matches_only){
		$status[1] = "all proteins";
		undef $matches_only;
	}

	# Selected to view matched proteins
	elsif ($selection eq "D" && !$matches_only){
		$matches_only = 1;
		$status[1] = "only proteins with matches";
		if ($printed_counter < 0){
			$locus_counter++;
			if ($locus_counter > scalar(@loci) - 1){
				$locus_counter = 0;
			}
			system "clear";
			next;
		}
	}

	# Selected to proceed to the next locus
	elsif ($selection eq "N"){
		$locus_counter++;
		if ($locus_counter > scalar(@loci) - 1){
			$locus_counter = 0;
		}
	}

	# Selected to proceed to the previous locus
	elsif ($selection eq "P"){
		$locus_counter--;
		if ($locus_counter == -1){
			$locus_counter = scalar(@loci) - 1;
		}
	}

	# Selected to jump to a specific locus
	elsif ($selection eq "J"){
		print "\n\tWhat locus would you like to jump to?\n\n\tSelection: ";
		chomp(my $locus = <STDIN>);
		my $index = 0;
		FOR: foreach my $locus_option (@loci){
			if ($locus =~ /$locus_option/){
				$locus_counter = $index;
				last FOR;
			}
		} 
	}

	# Selected to hide a specific predictor
	elsif ($selection eq "H" && $shown_predictors != 0){
		print "\n\t\tWhich of the following predictors you would like to hide? \n";
		foreach my $key (sort(keys(%viewable_predictors))){
			if ($viewable_predictors{$key}){
				print("\n\t\t\t$key");
			}
		}
		print "\n\n\t\tSelected predictor: ";
		chomp (my $hidden_predictor = <STDIN>);
		$hidden_predictor = uc($hidden_predictor);
		if ($viewable_predictors{$hidden_predictor}){
			undef $viewable_predictors{$hidden_predictor};
		}
	}

	# Selected to show a specific predictor
	elsif ($selection eq "S" && $shown_predictors != 3){
		print "\n\t\tWhich of the following predictors you would like to show? \n";
		foreach my $key (sort(keys(%viewable_predictors))){
			unless ($viewable_predictors{$key}){
				print "\n\t\t\t$key";
			}
		}
		print "\n\n\t\tSelected predictor: ";
		chomp (my $shown_predictor = <STDIN>);
		$shown_predictor = uc($shown_predictor);
		print $viewable_predictors{$shown_predictor}."\n";
		unless ($viewable_predictors{$shown_predictor}){
			$viewable_predictors{$shown_predictor} = 1;
		}
	}

	# Selected to exit the visualization script
	elsif ($selection eq "X"){
		print "\n\tProcess is terminating as requested...\n\tHave a nice day!\n\n";
		exit;
	}
	system "clear";
}