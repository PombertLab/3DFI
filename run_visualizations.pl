#!/usr/bin/perl
## Pombert Lab, Illinois Tech, 2021
my $name = "run_visualizations.pl";
my $version = "0.2.1";
my $updated = "2021-09-15";

use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;

my $usage = << "EXIT";
NAME        ${name}
VERSION     ${version}
UPDATED     ${updated}
SYNOPSIS    The purpose of this script it to visualize the predicted protein structures and their aligned homologs

USAGE       ${name} -r Results_3DFI

OPTIONS
-r (--results)  Results directory specified in run_3DFI.pl
EXIT

die("\n$usage\n") unless(@ARGV);

my $in_dir;
GetOptions(
    "r|results=s" => \$in_dir,
);

########################################################################################################################
# Parsing Results                                                                                                      #
########################################################################################################################

my $result_file = "$in_dir/Homology/GESAMT/All_GESAMT_matches_per_protein.tsv";
my $script = $0;
my ($file,$vis_dir) = fileparse($script);
$vis_dir .= "/Visualization/Helper_Scripts/";
my %color_scripts = ("ALPHAFOLD" => "$vis_dir/color_alphafold.py", "ROSETTAFOLD" => "$vis_dir/color_rosettafold.py");

open RESULTS, "<", $result_file or die("\n[E]  Unable to open $result_file: $!\n");

my $locus;
my @loci;
my %results;
my %predictors;
while (my $line = <RESULTS>){
    chomp($line);
    if($line =~ /^### (\S+?);/){ ### Insert proper regex ### 
        $locus = $1;
        push(@loci,$locus);
    }
    elsif($line =~ /^\S/){
        my @data = split("\t",$line);
        push(@{$results{$locus}},\@data);
        $predictors{uc($data[1])} = 1;
    }
}
close RESULTS;

########################################################################################################################
# Displaying Results                                                                                                   #
########################################################################################################################

system("clear");

## Keep track of the locus that we are currently working on so we can move forward and back in order
my $locus_counter = 0;
## Default into best view mode
my $best_only = 1;

## By default set all predictors available to VIEWABLE
my %viewable_predictors;
foreach my $key (keys(%predictors)){
    $viewable_predictors{$key} = 1;
}

## Loop until user quits the visualization script
WHILE: while(0==0){

    my $locus = $loci[$locus_counter];
    my %viewable_models;
    opendir(VIS,"$in_dir/Visualization");
    foreach my $obj (readdir(VIS)){
        unless($obj =~ /^\./){
            if(-e "$in_dir/Visualization/$obj"){
                if($viewable_predictors{$obj}){
                    opendir(MOD,"$in_dir/Visualization/$obj");
                    foreach my $mods (readdir(MOD)){
                        unless($mods =~ /^\./){
                            if($mods =~ /$locus/){
                                opendir(PDB,"$in_dir/Visualization/$obj/$mods");
                                foreach my $pdb (readdir(PDB)){
                                    if($pdb =~ /\.pdb$/){
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
    my @match_info = @{$results{$locus}};
    my $separater = "=" x 125;
    my $status;
    if($best_only){
        $status = "best";
    }
    else{
        $status = "all";
    }

    ####################################################################################################################
    # Printout Results                                                                                                 #
    ####################################################################################################################

    print("\n\t### $locus has ".scalar(@match_info)." matches. Currently in $status match mode ###\n\n");
    print("\t|$separater|\n");
    print("\t Selection  Q-Score     Predicted Structure     PDB-File => Chain     Structural Homolog Description\n");
    print("\t|$separater|\n");
    my $printed_counter = 0;
    foreach my $match (@match_info){
        unless($printed_counter > 4 && $best_only){
            my @match = @{$match};
            unless($viewable_predictors{$match[1]}){
                next;
            }
            ## Gathering data for result printout
            my ($model) = sprintf(" => Model %-3i",$match[0] =~ /\w+\-m(\d+)/);
            my $predictor = sprintf("%13s",$match[1]);
            my $match_id = sprintf("%11s",$match[2]);
            my $match_chain = sprintf(" => %-10s",$match[3]);
            my $q_score = sprintf("   %-6.3f",$match[4]);
            my $title = sprintf("%-15s",$match[-1]);
            my $formated_counter = sprintf("  %3s",$printed_counter+1);
            print("\t $formated_counter    ");
            print("$q_score");
            print("$predictor");
            print("$model");
            print("$match_id");
            print("$match_chain");
            print("$title");
            print("\n");
            $printed_counter++;
        }
    }
    print("\t|$separater|\n");

    ####################################################################################################################
    # Option Printouts                                                                                                 #
    ####################################################################################################################

    print("\n\n\tSelectable Options:\n\n");
    
    if($printed_counter > 0){
        print("\t\t[1-$printed_counter] Open corresponding match file\n");
        print("\t\t[M] To select predicted structure\n");
    }

    ## Quanity display options
    # All
    if($best_only){
        print("\n\t\t[A] Show ALL matches\n");
    }
    else{
        print("\n\t\t[B] Show BEST matches\n");
    }
    # Best
    
    ## Navigational options
    # Next
    print("\n\t\t[N] Proceed to the next locus\n");
    # Previous
    print("\t\t[P] Proceed to the previous locus\n");
    # Jump
    print("\t\t[J] Jump to a selected locus\n");
    my $shown_predictors = 0;
    foreach my $val (values(%viewable_predictors)){
        if($val){
            $shown_predictors++;
        }
    }

    ## Predictor display options
    # Hide
    if($shown_predictors == 3){
        print("\n\t\t[H] Hide a selected predictor\n");
    }
    # Show
    elsif($shown_predictors == 0){
        print("\n\t\t[S] Show a selected predictor\n");
    }
    # Hide/Show
    else{
        print("\n\t\t[H] Hide a selected predictor\n");
        print("\t\t[S] Show a selected predictor\n");
    }
    print("\n\t\t[X] Exit the visualization tool\n");

    ####################################################################################################################
    # Option Selection Processing                                                                                      #
    ####################################################################################################################

    print("\n\tSelection: ");
    chomp(my $selection = <STDIN>);
    $selection = uc($selection);

    # Selected to view a CXS file
    if($printed_counter > 0 && $selection =~ /([1-$printed_counter])/){
        my $selected_locus = $1 - 1;
        my @selected_data = @{$match_info[$selected_locus]};
        my ($model) = $selected_data[0] =~ /(\S+)/;
        my $predictor = $selected_data[1];
        my $match_id = lc($selected_data[2]);
        my $match_chain = $selected_data[3];
        my $outfile = "${predictor}/${model}/${model}_${match_id}_${match_chain}";
        system "chimerax 2>/dev/null $in_dir/Visualization/$outfile.cxs $vis_dir/restore_chimerax_session.py &";
    }

    # Selected to view a predicted PDB model
    elsif($selection eq "M"){
        print("\n\n\t\tWhich of the following predictors would you like to see viewable structural predictions for?\n\n");
        foreach my $predictor (sort(keys(%viewable_models))){
            if($viewable_models{$predictor}){
                print("\t\t\t$predictor\n");
            }
        }
        print("\n\t\tSelection: ");
        chomp(my $selected_predictor = <STDIN>);
        print("\n\n\t\t\tWhich of the following models would you like to visualize?\n\n");
        if($viewable_models{$selected_predictor}){
            foreach my $models (sort(keys(%{$viewable_models{$selected_predictor}}))){
                print("\t\t\t\t$models\n");
            }
            print("\n\t\t\tSelection: ");
            chomp(my $selected_model = <STDIN>);
            my $selected_model_path = $viewable_models{$selected_predictor}{$selected_model};
            my $colored_script = $color_scripts{$selected_predictor};
            unless($colored_script){ $colored_script = ""; }
            system "chimerax 2>/dev/null $selected_model_path $colored_script &";
        }
    }
    
    # Selected to view all results
    elsif($selection eq "A" && $best_only){
        undef $best_only;
    }

    # Selected to view best results
    elsif($selection eq "B" && !$best_only){
        $best_only = 1;
    }

    # Selected to proceed to the next locus
    elsif($selection eq "N"){
        $locus_counter++;
        if($locus_counter > scalar(@loci) - 1){
            $locus_counter = 0;
        }
    }

    # Selected to proceed to the previous locus
    elsif($selection eq "P"){
        $locus_counter--;
        if($locus_counter == -1){
            $locus_counter = scalar(@loci) - 1;
        }
    }
    
    # Selected to jump to a specific locus
    elsif($selection eq "J"){
        print("\n\tWhat locus would you like to jump to?\n\n\tSelection: ");
        chomp(my $locus = <STDIN>);
        my $index = 0;
        FOR: foreach my $locus_option (@loci){
            if($locus =~ /$locus_option/){
                $locus_counter = $index;
                last FOR;
            }
            $index++;
        } 
    }

    # Selected to hide a specific predictor
    elsif($selection eq "H" && $shown_predictors != 0){
        print("\n\tWhich of the following predictors you would like to hide? \n");
        foreach my $key (sort(keys(%viewable_predictors))){
            if($viewable_predictors{$key}){
                print("\n\t$key");
            }
        }
        print("\n\n\tSelected predictor: ");
        chomp(my $hidden_predictor = <STDIN>);
        $hidden_predictor = uc($hidden_predictor);
        if($viewable_predictors{$hidden_predictor}){
            undef $viewable_predictors{$hidden_predictor};
        }
    }

    # Selected to show a specific predictor
    elsif($selection eq "S" && $shown_predictors != 3){
        print("\n\tWhich of the following predictors you would like to show? \n");
        foreach my $key (sort(keys(%viewable_predictors))){
            unless($viewable_predictors{$key}){
                print("\n\t$key");
            }
        }
        print("\n\n\tSelected predictor: ");
        chomp(my $shown_predictor = <STDIN>);
        $shown_predictor = uc($shown_predictor);
        print($viewable_predictors{$shown_predictor}."\n");
        unless($viewable_predictors{$shown_predictor}){
            $viewable_predictors{$shown_predictor} = 1;
        }
    }
    
    # Selected to exit the visualization script
    elsif($selection eq "X"){
        print("\n\tProcess is terminating as requested...\n\tHave a nice day!\n\n");
        exit;
    }
    system("clear");
}