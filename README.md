<p align="left"><img src="https://github.com/PombertLab/3DFI/blob/master/Images/Logo.png" alt="3DFI - Three-dimensional function inference" width="800"></p>

The 3DFI pipeline automates protein structure predictions, structural homology searches and alignments with putative structural homologs at the genome scale. Protein structures predicted in PDB format are searched against a local copy of the [RSCB PDB](https://www.rcsb.org/) database with GESAMT (General Efficient Structural Alignment of Macromolecular Targets) from the [CCP4](https://www.ccp4.ac.uk/) package. Known PDB structures can also be searched against sets of predicted structures to identify potential structural homologs in predicted datasets. These structural homologs are then aligned for visual inspection with [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html).

<a href="https://zenodo.org/badge/latestdoi/279375246"><p align="right"><img src="https://zenodo.org/badge/279375246.svg" alt="DOI"></a>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: TOC</i></b></summary>

## Table of contents
* [Introduction](#introduction)
* [Getting started](#getting-started)
	* [Recommended hardware](#recommended-hardware)
	* [Software requirements](#software-requirements)
	* [Installing 3DFI](#installing-3DFI)
		* [Initial setup](#initial-setup)
		* [Downloading the 3DFI databases](#downloading-the-3DFI-databases)
	* [Using 3DFI](#Using-3DFI)
		* [A case example - Unknown proteins from Microsporidia](#a-case-example---unknown-proteins-from-microsporidia)
			* [Interpreting the results](#Interpreting-the-results)
* [The 3DFI pipeline process in detail](#the-3DFI-ipeline-process-in-detail)
	* [Preparing FASTA files](#preparing-fasta-files)
	* [3D structure prediction](#3D-structure-prediction)
		* [AlphaFold2](#AlphaFold2---deep-learning-based-protein-structure-modeling)
		* [RoseTTAFOLD](#RoseTTAFOLD---deep-learning-based-protein-structure-modeling)
		* [RaptorX](#Raptorx---template-based-protein-structure-modeling)
	* [Structural homology searches](#Structural-homology-searches)
		* [Downloading PDB files from RCSB](#downloading-PDB-files-from-RCSB)
		* [Creating a list of PDB titles](#creating-a-list-of-PDB-titles)
		* [Creating or updating a GESAMT database](#creating-or-updating-a-GESAMT-database)
		* [Structural homology searches with GESAMT](#structural-homology-searches-with-GESAMT)
		* [Parsing the output of GESAMT searches](#Parsing-the-output-of-GESAMT-searches)
	* [Structural alignment and visualization](#Structural-alignment-and-visualization)
		* [About alignment and visualization](#About-alignment-and-visualization)
		* [Aligning protein structures and inspecting alignments with ChimeraX](#Aligning-protein-structures-and-inspecting-alignments-with-ChimeraX)
		* [Coloring AlphaFold2 or RoseTTAFold predictions per confidence scores](#Coloring-AlphaFold2-or-RoseTTAFold-predictions-per-confidence-scores)
* [Miscellaneous](#miscellaneous)
	* [Useful scripts](#useful-scripts)
	* [Alternate predictors](#alternate-predictors)
    	* [trRosetta](#trRosetta---deep-learning-based-protein-structure-modeling)
		* [trRosetta2](#trRosetta2---deep-learning-based-protein-structure-modeling)
* [Funding and acknowledgments](#Funding-and-acknowledgments)
* [How to cite](#how-to-cite)
* [References](#references)
</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: Introduction</i></b></summary>

### Introduction
###### About function inferences
Inferring the function of proteins using computational approaches usually involves performing some sort of homology search based on sequences or structures. In sequence-based searches, nucleotide or amino acid sequences are queried against known proteins or motifs using tools such as [BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi), [DIAMOND](https://github.com/bbuchfink/diamond), [HHBLITS](https://github.com/soedinglab/hh-suite) or [HMMER](http://hmmer.org/), but those searches may fail if the proteins investigated are highly divergent. In structure-based searches, proteins are searched instead at the 3D level for structural homologs.

###### Why structural homologs?
Because structure often confers function in biology, structural homologs often share similar functions, even if the building blocks are not the same (*i.e.* a wheel made of wood or steel is still a wheel regardless of its composition). Using this approach, we might be able to infer putative functions for proteins that share little to no similarity at the sequence level with known proteins, assuming that a structural match can be found.

###### What is needed for structure-based homology searches?
To perform structure-based predictions we need 3D structures — either determined experimentally or predicted computationally — that we can query against other structures, such as those from the [RCSB PDB](https://www.rcsb.org/). We also need tools that can search for homology at the structural level. Several tools are now available to predict protein structures, many of which are implemented as web servers for ease of use. A listing can be found at [CAMEO](https://www.cameo3d.org/), a website that evaluates their accuracy and reliability. Fewer tools are available to perform searches at the 3D levels (*e.g.* SSM and GESAMT). SSM is implemented in [PDBeFold](https://www.ebi.ac.uk/msd-srv/ssm/) while GESAMT is part of the [CCP4](https://www.ccp4.ac.uk/) package.

###### Why this pipeline?
Although predicting the structure of a protein and searching for structural homologs can be done online, for example by using [SWISS-MODEL](https://swissmodel.expasy.org/) and [PDBeFold](https://www.ebi.ac.uk/msd-srv/ssm/), genomes often code for thousands of proteins and applying this approach on a genome scale using web portals would be time consuming and error prone. We implemented the 3DFI pipeline to enable the use of structure-based homology searches at a genome-wide level from the command line.
</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: Getting started</i></b></summary>

### Getting started
#### Recommended hardware
The 3DFI pipeline was tested on Fedora 33/34 Linux workstations (*Workstation 1* - AMD Ryzen 5950X, NVIDIA RTX A6000, 128 Gb RAM; *Workstation 2* - AMD Ryzen 3900X, NVIDIA RTX 2070S, 64 Gb RAM; *Workstation 3* - 2x Intel Xeon E5-2640, NVIDIA GTX 1070, 128 Gb RAM).

The following hardware is recommended to use 3DFI:
- A CUDA-enabled NVIDIA GPU (>= 24 Gb VRAM; >= 6.1 compute capability)
- A fast 4 Tb+ SSD
- At least 64 Gb of RAM 

1. The deep-learning based protein structure predictors [AlphaFold2](https://github.com/deepmind/alphafold) and [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) leverage the NVIDIA CUDA framework to accelerate computations on existing GPUs. Although small proteins might fit within 8Gb of video RAM (VRAM), larger proteins will require more VRAM (the RoseTTAFold authors used a 24 Gb VRAM GPU in their [paper](https://pubmed.ncbi.nlm.nih.gov/34282049/)). Both [AlphaFold2](https://github.com/deepmind/alphafold) and [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) can run without GPU acceleration, but doing so is much slower and is only recommended for small numbers of proteins. The template-based protein structure predictor [RaptorX](http://raptorx.uchicago.edu/) does not require any GPU.

2. Both [AlphaFold2](https://github.com/deepmind/alphafold) and [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) leverage hhblits from [HH-suite3](https://github.com/soedinglab/hh-suite) to perform hidden Markov model searches as part of their protein structure prediction processes. These searches are I/O intensive and can be greatly sped up by putting the databases to query onto an NVME SSD. Because the Alphafold databases are over 2.2 Tb in size once uncompressed, a fast SSD of at least 4TB is recommended to store all databases in a single location. Running hhblits on hard drives is possible (if slower), but we have seen hhblits searches crash on a few occasions when an hard drive's I/O was being saturated.

3. Using [AlphaFold2](https://github.com/deepmind/alphafold) with its --full_dbs preset can require a large amount of system memory. The AlphaFold --reduced_dbs preset uses a smaller memory footprint. [3DFI](https://github.com/PombertLab/3DFI) was tested on machines with a minimum of 64 Gb of RAM but may work on machines with more modest specifications.

4. If investigating large datasets, a 10 Tb+ storage solution is recommended (hard drives are fine) to store the results. AlphaFold often outputs over 50 Gb of data per protein.

#### Software requirements
The 3DFI pipeline requires the following software to perform protein structure predictions, structural homology searches/alignments and visualization:
1. The lightweight [aria2](https://aria2.github.io/) download utility tool.
2. At least one of the following protein structure prediction tools:
	- A [customized](https://github.com/PombertLab/alphafold) version of [AlphaFold2](https://github.com/deepmind/alphafold) (Deep-learning-based)
		- Requires [Docker](https://www.docker.com/)
	- [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) (Deep-learning-based)
		- Requires [Conda](https://docs.conda.io/en/latest/), [PyRosetta](http://www.pyrosetta.org/) (Python-3.7 Release)
	- [RaptorX](http://raptorx.uchicago.edu/) (Template-based)
		- Requires [MODELLER](https://salilab.org/modeller/)
3. A structural homology search tool:
	- GESAMT via [CCP4](https://www.ccp4.ac.uk/)
4. An alignment/visualization tool:
	- [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html)
5. [Perl5](https://www.perl.org/) and the additonal scripting module:
	- [PerlIO::gzip](https://metacpan.org/pod/PerlIO::gzip)

##### Aria2
Aria2 is a lightweight utility tool that can resume partial downloads. 3DFI uses this tool to download its databases. On Fedora, aria2 can be installed from the DNF package manager:
```Bash
sudo dnf install aria2
```

##### Protein structure prediction tools
The [customized](https://github.com/PombertLab/alphafold) version of AlphaFold can be installed together with [RaptorX](http://raptorx.uchicago.edu/) and/or [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) with [setup_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/setup_3DFI.pl) as described [below](https://github.com/PombertLab/3DFI#installing-3DFI). Docker and/or Conda should be installed prior to running setup_3DFI.pl. Notes on how to install Docker and Conda on Fedora are provided [here](https://github.com/PombertLab/3DFI/blob/master/Notes/Installation_notes.sh) for convenience.

Due to its excellent results in the [CASP14](https://predictioncenter.org/casp14/) competition (see this Nature news [article](https://www.nature.com/articles/d41586-020-03348-4)), we recommend using [AlphaFold2](https://github.com/deepmind/alphafold) if a single predictor is desired.

[RaptorX](http://raptorx.uchicago.edu/) is an interesting option if no CUDA-enabled GPU is available. Its template-based approach can work where deep-learning methods do not, making it an interesting alternative even if GPUs are available. We thank Professor Jinbo Xu for allowing us to redistribute RaptorX with 3DFI for non-commercial purposes.

[RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) is also an excellent choice but a PyRosetta [license](http://www.pyrosetta.org/) and the latest PyRosetta4.Release.python37.*.tar.bz2 release should be obtained prior to running [setup_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/setup_3DFI.pl).

##### Modeller
RaptorX requires [Modeller](https://salilab.org/modeller/). The license for Modeller can be requested [here](https://salilab.org/modeller/registration.html). Modeller can be downloaded [here](https://salilab.org/modeller/download_installation.html). To install Modeller on RedHat/Fedora:
```Bash
LICENSE=XXXXX ## replace XXXXX by modeller license
MODELLER=modeller-10.1-1.x86_64.rpm
sudo env KEY_MODELLER=$LICENSE rpm -Uvh $MODELLER
```

##### The CCP4 package
The [CCP4](https://www.ccp4.ac.uk/) package can be installed by following the prompts from its graphical user interface. The gesamt program required by 3DFI will be located inside the bin subdirectory, which should be added to the **$PATH** environment variable.

```Bash
export CCP4=/opt/xtal/CCP4/ccp4-7.1/bin/
export PATH=$PATH:$CCP4
```

##### ChimeraX
[ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html) is provided as .deb and .rpm packages for Debian- and RedHat-based Linux distributions. On Fedora, ChimeraX can be installed from the command line with the DNF package manager.
```Bash
sudo dnf install ucsf-chimerax-*.rpm
```

##### Perl modules
The 3DFI pipeline uses standard Perl modules installed together with Perl, with the exception of PerlIO::gzip which is used to read compressed GZIPPED files on the fly. On Fedora, the PerlIO::gzip module can be installed from the DNF package manager with:
```
sudo dnf install perl-PerlIO-gzip
```

The module can also be installed from CPAN by invoking 'cpan' from the command line followed by entering 'install PerlIO::gzip' in the prompt:
```
cpan[1]> install PerlIO::gzip
cpan[2]> exit
```

#### Installing 3DFI
The 3DFI pipeline can be downloaded directly from GitHub with git clone. 
```Bash
## To download 3DFI from GitHub:
git clone https://github.com/PombertLab/3DFI.git
```

##### Initial setup
The [setup_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/setup_3DFI.pl) script can be used to install AlphaFold, RaptorX and/or RoseTTAFold and to set up the 3DFI environment variables. The script can also add the 3DFI installation folder and it subdirectories to the **\$PATH** environment variable (if desired) from the interactive prompts. 

- When run, the 3DFI pipeline will search for the following environment variables (**\$ALPHAFOLD_HOME**, **\$ROSETTAFOLD_HOME** and/or **\$RAPTORX_HOME**) depending on the requested protein structure predictor(s).

- The 3DFI installation and database directories will be set as environment variables (**\$TDFI_HOME** and **\$TDFI_DB**, respectively).

To install AlphaFold, RaptorX and RoseTTAFold and set the 3DFI environment variables in the ~/.bashrc with setup_3DFI.pl:
```Bash
export CONFIG=~/.bashrc
export DATABASE=/media/databases/3DFI
export PYROSETTA=~/Downloads/PyRosetta4.Release.python37.*.tar.bz2

cd 3DFI/
./setup_3DFI.pl \
  -c $CONFIG \
  -d $DATABASE \
  -i alphafold raptorx rosettafold \
  -pyr $PYROSETTA
```
<details open>
  <summary>Options for setup_3DFI.pl are:</summary>

```
-c (--config)	Configuration file to edit/create (e.g. ~/.bashrc)
-w (--write)	Write mode: (a)ppend or (o)verwrite [Default: a]
-d (--dbdir)	3DFI databases directory ($TDFI_DB)
-p (--path)	3DFI installation directory ($TDFI_HOME) [Default: ./]

## Protein structure predictors 
-i (--install)		3D structure predictor(s) to install (alphafold raptorx and/or rosettafold)
-pyr (--pyrosetta)	PyRosetta4 [Python-3.7.Release] .tar.bz2 archive to install
			# Download - https://www.pyrosetta.org/downloads#h.xe4c0yjfkl19
			# License - https://els2.comotion.uw.edu/product/pyrosetta
```
</details>

<details open>
  <summary>Once configured, the environment variables should look like this:</summary>

```bash
### 3DFI environment variables
export TDFI_HOME=/opt/3DFI
export TDFI_DB=/media/databases/3DFI

### 3DFI environment variables for protein structure predictor(s)
export RAPTORX_HOME=/opt/3DFI/3D/RaptorX
export ROSETTAFOLD_HOME=/opt/3DFI/3D/RoseTTAFold
export ALPHAFOLD_HOME=/opt/3DFI/3D/alphafold

### 3DFI PATH variables
PATH=$PATH:/opt/3DFI
PATH=$PATH:/opt/3DFI/Prediction/RaptorX
PATH=$PATH:/opt/3DFI/Prediction/AlphaFold2
PATH=$PATH:/opt/3DFI/Prediction/RoseTTAFold
PATH=$PATH:/opt/3DFI/Homology_search
PATH=$PATH:/opt/3DFI/Visualization
PATH=$PATH:/opt/3DFI/Misc_tools

export PATH
```
</details>

##### Downloading the 3DFI databases
The [create_3DFI_db.pl](https://github.com/PombertLab/3DFI/blob/master/create_3DFI_db.pl) script can be used to download the 3DFI databases. If the **\$TDFI_DB** environment variable is set, [create_3DFI_db.pl](https://github.com/PombertLab/3DFI/blob/master/create_3DFI_db.pl) can be used without invoking the -d command line switch.

To download all 3DFI databases [~770 Gb; 3.2 Tb unpacked] with create_3DFI_db.pl, unpack them, then delete the packed archives:
```Bash
cd $TDFI_HOME
./create_3DFI_db.pl --all --delete
```
<details open>
  <summary>Options for create_3DFI_db.pl are:</summary>

```
-a (--all)	Download all databases: RCSB, ALPHAFOLD, ROSETTAFOLD, RAPTORX
-d (--db)	Target 3DFI database location [Default: $TDFI_DB]

# Download specific databases:
--rcsb		RCSB PDB/GESAMT
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
--update_gesamt	Update an existing GESAMT archive
-c (--cpu)	Number of CPUs to create/update the GESAMT archive [Default: 10]

### Download size / disk usage
# TOTAL				669 Gb / 3.2 Tb
# RSCB PDB			39 Gb / 42 Gb inflated
# BFD (AlphaFold/RoseTTAFold)	272 Gb / 1.8 Tb inflated
# AlphaFold (minus BFD)		176 Gb / 0.6 Tb inflated
# RoseTTAFold (minus BFD)	146 Gb / 849 Gb inflated
# RaptorX			37 Gb / 76 Gb inflated
```
</details>

<details open>
  <summary>Once created, the content of the 3DFI database directory should look like this:</summary>

```Bash
ls -l $TDFI_DB

total 2758236
drwxr-xr-x     2 jpombert jpombert       4096 Sep 22 08:38 ALPHAFOLD
drwxr-xr-x     2 jpombert jpombert       4096 Sep 22 08:38 BFD
drwxr-xr-x.    9 jpombert jpombert       4096 Jul 12 15:52 RAPTORX
drwxr-xr-x     2 jpombert jpombert      49152 Sep 21 15:33 RCSB_GESAMT
drwxr-xr-x. 1062 jpombert jpombert      20480 Jul  4  2020 RCSB_PDB
-rw-r--r--     1 jpombert jpombert   36715353 Sep 21 08:50 RCSB_PDB_titles.tsv
drwxr-xr-x     5 jpombert jpombert       4096 Sep 22 08:48 ROSETTAFOLD
```
</details>
</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: Using 3DFI</i></b></summary>

#### Using 3DFI
The 3DFI pipeline can be lauched with the [run_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/run_3DFI.pl) master script, which will perform the following steps:
1. Prepare FASTA files (single or multifasta) for protein folding
2. Run the selected protein structure predictor(s)
3. Perform structural homology searches between predicted structures and [RCSB PDB](https://www.rcsb.org/) proteins
4. Align the predicted proteins with their structural homologs for later visualization with ChimeraX

The 3DFI pipeline can be run on one (or more) set of single/multifasta files using all three predictors with the following command line:

```bash
export OUTPUT=Results_3DFI

run_3DFI.pl \
  -f *.fasta \
  -o $OUTPUT \
  -p alphafold rosettafold raptorx \
  -c 16
```

<details open>
  <summary>General options for run_3DFI.pl are:</summary>

```
-h (--help)		Print detailed options
-f (--fasta)		Proteins to query (in FASTA format)
-o (--out)		Output directory [Default: Results_3DFI]
-p (--pred)		Structure predictor(s): alphafold, rosettafold, and/or raptorx
-c (--cpu)		# of CPUs to use [Default: 10]
-3do (--3D_only)	3D folding only; no structural homology search(es) / structural alignment(s)
-v (--viz)		Turn on visualization once the structural homology searches are completed
```
</details>

- Because the protein structure prediction step is time-consuming even with GPU acceleration, we recommend running only one predictor at a time if using large protein datasets. The average AlphaFold folding time on our AMD Ryzen 5950X/NVIDIA RTX A6000 workstation was 31.59 minutes per protein (~ 50 proteins/day) on a ~1,900 protein dataset, with computation times as low and high as 9.07 and 4282.32 minutes per protein, respectively.

- If interrupted, the pipeline can be resumed by re-entering the same command line. Previously computed protein structures, structural matches and alignments will be skipped.

<details open>
  <summary>Advanced options for run_3DFI.pl are:</summary>

```Bash
## FASTA preparation
--window		Split individual fasta sequences into fragments using sliding windows [Default: off]
--win_size		Size of the the sliding window [Default: 250 (aa)]
--win_overlap		Sliding window overlap [Default: 100 (aa)]

## 3D Folding options
-n (--nogpu)		ALPHAFOLD/ROSETTAFOLD: Turn off GPU acceleration / use CPU only
-m (--maxdate)		ALPHAFOLD: --max_template_date option (YYYY-MM-DD) [Default: current date]
-k (--ranks)		RAPTORX: Number of top ranks to model [Default: 5]
--modeller		RAPTORX: Modeller version [Default: mod10.1]

## Structural homology / alignment
-d (--db)		3DFI database location containing the RCSB PDB files / GESAMT archive [Default: $TDFI_DB]
-q (--qscore)		Mininum Q-score to keep [Default: 0.3]
-b (--best)		Keep the best match(es) only (top X hits) [Default: 5]
--query			Models to query per protein and predictor: all or best [Default: all]
```
</details>

#### A case example - Unknown proteins from Microsporidia
*Encephalitozoon cuniculi* is a fungal-like [NIAID category B pathogen](https://www.niaid.nih.gov/research/emerging-infectious-diseases-pathogens) belonging to the phylum Microsporidia. Proteins encoded in *Encephalitozoon* genomes are highly divergent such that roughly half cannot be identified using sequence-based homology approaches. The [sequences.fasta](https://github.com/PombertLab/3DFI/tree/master/Examples/FASTA/sequences.fasta) file from 3DFI/Examples/FASTA is a multifasta file containing a total of 3 small proteins from [*Encephalitozoon cuniculi* GB-M1](https://microsporidiadb.org/micro/app/downloads/Current_Release/EcuniculiGBM1/) that cannot be identified by traditional sequence-based approaches. Running [InterProScan](http://www.ebi.ac.uk/interpro/search/sequence/) searches using these proteins as queries return no results, *e.g.*:

<p align="center"><img src="https://github.com/PombertLab/3DFI/blob/master/Images/no_homology.png" alt="Example of a lack of sequence homology with InterProScan 5" width="1200"></p>  

\
The 3DFI pipeline can be used to predict the 3D structure of these proteins and search for structural homologs in the 3D space to see if putative functions can be assigned to these proteins based on matches with proteins from the [RCSB](https://www.rcsb.org/) Protein Data Bank.

To use the 3DFI pipeline on the provided examples using 16 CPU cores together with CUDA-enabled GPU(s) (whenever possible) for [AlphaFold2](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/af2_installation_notes.sh), [RoseTTAFold](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/rfold_installation_notes.sh) and [RaptorX](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx_installation_notes.sh), we can type:

```Bash
## Creating a working directory to store results from 3DFI
export RESULTS=~/Results_3DFI

## Running 3DFI with 16 CPU cores and the alphafold, rosettafold and raptorx
## protein structure predictors; to launch the visualization step
## automatically afterwards, add the -v flag
run_3DFI.pl \
  -f $TDFI_HOME/Examples/FASTA/*.fasta \
  -o $RESULTS \
  -c 16 \
  -p alphafold rosettafold raptorx
```

In the above example, structural homology searches will be performed automatically against the databases located in **$TDFI_DB**. On our AMD Ryzen 5950X/NVIDIA RTX A6000 workstation (equipped with an NVME SSD), the process from start to finish took 1 hour 45 minutes *vs.* 4 hours 25 minutes on our Intel Xeon E5-2640/NVIDIA GTX 1070 workstation (equipped with a standard 7200 RPM hard drive). In contrast, running the pipeline on the same machines using AlphaFold as the only protein structure predictor took 51 minutes *vs.* 1 hour 59 minutes. 

<details>
  <summary> Click here to show/hide details about the contents of the 3DFI output folder.</summary>

The 3DFI output data is partitionned in 4 subdirectories:
1. FASTA
2. Folding
3. Homology
4. Visualization

- The FASTA subdirectory contains single FASTA files created by the pipeline from files specified with -f.
- The Folding subdirectory contains protein stuctures generated by the requested protein structure predictor(s).
- The Homology subdirectory contains the results of GESAMT homology searches against RCSB PDB files.
- The Visualization subdirectory contains alignments in .cxs format between predicted structures and putative structural analogs for later visualization/inspection with ChimeraX.

Once run_3DFI.pl completed all corresponding tasks, the content of the $RESULTS folder should look like this:

```Bash
ls -l $RESULTS/*

RESULTS/FASTA:
total 12
-rw-r--r--. 1 jpombert jpombert 131 Sep 15 12:07 ECU03_1140.fasta
-rw-r--r--. 1 jpombert jpombert 162 Sep 15 12:07 ECU06_1350.fasta
-rw-r--r--. 1 jpombert jpombert 106 Sep 15 12:07 ECU08_1425.fasta

RESULTS/Folding:
total 0
drwxr-xr-x. 1 jpombert jpombert  88 Sep 15 13:57 ALPHAFOLD_3D
drwxr-xr-x. 1 jpombert jpombert 510 Sep 15 13:57 ALPHAFOLD_3D_Parsed
drwxr-xr-x. 1 jpombert jpombert  74 Sep 15 15:44 RAPTORX_3D
drwxr-xr-x. 1 jpombert jpombert  90 Sep 15 14:31 ROSETTAFOLD_3D
drwxr-xr-x. 1 jpombert jpombert 102 Sep 15 14:43 ROSETTAFOLD_3D_Parsed

RESULTS/Homology:
total 0
drwxr-xr-x. 1 jpombert jpombert 542 Sep 15 16:27 GESAMT
drwxr-xr-x. 1 jpombert jpombert 492 Sep 15 16:27 LOGS

RESULTS/Visualization:
total 0
drwxr-xr-x. 1 jpombert jpombert 390 Sep 15 16:27 ALPHAFOLD
drwxr-xr-x. 1 jpombert jpombert 390 Sep 15 16:30 RAPTORX
drwxr-xr-x. 1 jpombert jpombert  78 Sep 15 16:30 ROSETTAFOLD
```

In the Folding/ subdirectory, the ALPHAFOLD_3D / ROSETTAFOLD_3D folders contain the unmodified outputs from the corresponding protein stucture predictors while the ALPHAFOLD_3D_Parsed / ROSETTAFOLD_3D_Parsed folders contain PDB files that have been renamed after the sequences being folded (for convenience).

For example:

<details open>
  <summary>Content of the ALPHAFOLD_3D folder</summary>

```Bash
ls -l $RESULTS/Folding/ALPHAFOLD_3D
total 32
-rw-r--r--. 1 jpombert jpombert 472 Sep 15 13:57 alphafold2.log
drwxr-xr-x. 1 jpombert jpombert 792 Sep 15 12:46 ECU03_1140
drwxr-xr-x. 1 jpombert jpombert 792 Sep 15 13:23 ECU06_1350
drwxr-xr-x. 1 jpombert jpombert 792 Sep 15 13:57 ECU08_1425
```
</details>

<details open>
  <summary>Content of an ALPHAFOLD_3D subdirectory</summary>

```Bash

ls -l $RESULTS/Folding/ALPHAFOLD_3D/ECU03_1140/

total 47388
-rw-r--r--. 1 jpombert jpombert 1072239 Sep 15 12:36 features.pkl
drwxr-xr-x. 1 jpombert jpombert     134 Sep 15 12:36 msas
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_0.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_1.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_2.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_3.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_4.pdb
-rw-r--r--. 1 jpombert jpombert     330 Sep 15 12:46 ranking_debug.json
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:39 relaxed_model_1.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:41 relaxed_model_2.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:43 relaxed_model_3.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:45 relaxed_model_4.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 relaxed_model_5.pdb
-rw-r--r--. 1 jpombert jpombert 9084306 Sep 15 12:38 result_model_1.pkl
-rw-r--r--. 1 jpombert jpombert 9084306 Sep 15 12:41 result_model_2.pkl
-rw-r--r--. 1 jpombert jpombert 9127362 Sep 15 12:42 result_model_3.pkl
-rw-r--r--. 1 jpombert jpombert 9127362 Sep 15 12:44 result_model_4.pkl
-rw-r--r--. 1 jpombert jpombert 9127362 Sep 15 12:46 result_model_5.pkl
-rw-r--r--. 1 jpombert jpombert     772 Sep 15 12:46 timings.json
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:38 unrelaxed_model_1.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:41 unrelaxed_model_2.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:42 unrelaxed_model_3.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:44 unrelaxed_model_4.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:46 unrelaxed_model_5.pdb
```
</details>
<details open>
  <summary>Content of the ALPHAFOLD_3D_parsed subdirectory</summary>

```Bash
ls -l $RESULTS/Folding/ALPHAFOLD_3D_Parsed
total 2780
-rw-r--r--. 1 jpombert jpombert 149210 Sep 15 13:57 ECU03_1140-m1.pdb
-rw-r--r--. 1 jpombert jpombert 149210 Sep 15 13:57 ECU03_1140-m2.pdb
-rw-r--r--. 1 jpombert jpombert 149210 Sep 15 13:57 ECU03_1140-m3.pdb
-rw-r--r--. 1 jpombert jpombert 149210 Sep 15 13:57 ECU03_1140-m4.pdb
-rw-r--r--. 1 jpombert jpombert 149210 Sep 15 13:57 ECU03_1140-m5.pdb
-rw-r--r--. 1 jpombert jpombert 184040 Sep 15 13:57 ECU06_1350-m1.pdb
-rw-r--r--. 1 jpombert jpombert 183878 Sep 15 13:57 ECU06_1350-m2.pdb
-rw-r--r--. 1 jpombert jpombert 183878 Sep 15 13:57 ECU06_1350-m3.pdb
-rw-r--r--. 1 jpombert jpombert 183878 Sep 15 13:57 ECU06_1350-m4.pdb
-rw-r--r--. 1 jpombert jpombert 183878 Sep 15 13:57 ECU06_1350-m5.pdb
-rw-r--r--. 1 jpombert jpombert 125396 Sep 15 13:57 ECU08_1425-m1.pdb
-rw-r--r--. 1 jpombert jpombert 125396 Sep 15 13:57 ECU08_1425-m2.pdb
-rw-r--r--. 1 jpombert jpombert 125396 Sep 15 13:57 ECU08_1425-m3.pdb
-rw-r--r--. 1 jpombert jpombert 125396 Sep 15 13:57 ECU08_1425-m4.pdb
-rw-r--r--. 1 jpombert jpombert 125396 Sep 15 13:57 ECU08_1425-m5.pdb
```

In the above, AlphaFold ranks the models predicted from best (0) to worst (4); the *-m1.pdb to *-m5.pdb files representing the ranked_0.pdb to ranked_4.pdb files for the corresponding proteins.
</details>
</details>  

\
The overall process of performing protein structure predictions, runnning structural homology searches, and aligning predicted structures to possible matches can take a very long time on large datasets. If long computation times are expected, we suggest running the visualization step independently after completion of the run_3DFI.pl tasks. The visualization of the alignments is not automatic and requires manual curation. This step is not computationally intensive and can be performed on machines with modest specifications.

Structural homologs found with 3DFI will be summarized in the [All_GESAMT_matches_per_protein.tsv](https://github.com/PombertLab/3DFI/blob/master/Examples/Results_3DFI/Homology/GESAMT/All_GESAMT_matches_per_protein.tsv) file located in the Homology/GESAMT subdirectory. This file ranks matches by decreasing Q-scores (a measure of structural similarity ranging from 0 to 1). For brevity, only the best match to a unique RCSB PDB + chain entry is listed.

Structural alignments can be visualized with [run_visualizations.pl](https://github.com/PombertLab/3DFI/blob/master/run_visualizations.pl) on the output of [run_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/run_3DFI.pl):
```Bash
run_visualizations.pl -r $RESULTS
```

The output should result in something similar to the following:
```
### ECU03_1140 has 15 matches. ###

  - Currently in all match mode 
  - Viewing only proteins with matches

|=============================================================================================================================|
  Selection  Q-Score     Predicted Structure     PDB-File => Chain     Structural Homolog Description
|=============================================================================================================================|
      1       0.822       RAPTORX => Model 4         3KDF => B         REPLICATION PROTEIN A 32 KDA SUBUNIT
      2       0.785       RAPTORX => Model 4         1QUQ => A         PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
      3       0.785       RAPTORX => Model 4         3KDF => D         REPLICATION PROTEIN A 32 KDA SUBUNIT
      4       0.784       RAPTORX => Model 4         1L1O => E         REPLICATION PROTEIN A 32 KDA SUBUNIT
      5       0.782       RAPTORX => Model 4         2PI2 => D         REPLICATION PROTEIN A 32 KDA SUBUNIT
|=============================================================================================================================|


Selectable Options:

  [1-5] Open corresponding match file
  [M] To select predicted structure

  [A] Show ALL matches
  [C] Include predicted structures without matches

  [N] Proceed to the next locus
  [P] Proceed to the previous locus
  [J] Jump to a selected locus

  [H] Hide a selected predictor

  [X] Exit the visualization tool

Selection: 

```

\
By default, only the top 5 matches are shown for the given protein. Selecting [A] will reveal all corresponding matches:

```
### ECU03_1140 has 15 matches. ###

  - Currently in all match mode 
  - Viewing only proteins with matches

|=============================================================================================================================|
  Selection  Q-Score     Predicted Structure     PDB-File => Chain     Structural Homolog Description
|=============================================================================================================================|
      1       0.822       RAPTORX => Model 4         3KDF => B         REPLICATION PROTEIN A 32 KDA SUBUNIT
      2       0.785       RAPTORX => Model 4         1QUQ => A         PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
      3       0.785       RAPTORX => Model 4         3KDF => D         REPLICATION PROTEIN A 32 KDA SUBUNIT
      4       0.784       RAPTORX => Model 4         1L1O => E         REPLICATION PROTEIN A 32 KDA SUBUNIT
      5       0.782       RAPTORX => Model 4         2PI2 => D         REPLICATION PROTEIN A 32 KDA SUBUNIT
      6       0.755       RAPTORX => Model 3         1L1O => B         REPLICATION PROTEIN A 32 KDA SUBUNIT
      7       0.753       RAPTORX => Model 3         2PI2 => B         REPLICATION PROTEIN A 32 KDA SUBUNIT
      8       0.676       RAPTORX => Model 1         1QUQ => C         PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
      9       0.670       RAPTORX => Model 1         3KF6 => A         PROTEIN STN1   
     10       0.655       RAPTORX => Model 1         4GNX => B         PUTATIVE UNCHARACTERIZED PROTEIN
     11       0.654     ALPHAFOLD => Model 3         2PQA => A         REPLICATION PROTEIN A 32 KDA SUBUNIT
     12       0.649     ALPHAFOLD => Model 5         4GOP => Y         PUTATIVE UNCHARACTERIZED PROTEIN
     13       0.645     ALPHAFOLD => Model 2         4GOP => B         PUTATIVE UNCHARACTERIZED PROTEIN
     14       0.632       RAPTORX => Model 2         4JOI => A         CST COMPLEX SUBUNIT STN1
     15       0.530       RAPTORX => Model 5         4GNX => Y         PUTATIVE UNCHARACTERIZED PROTEIN
|=============================================================================================================================|


Selectable Options:

  [1-15] Open corresponding match file
  [M] To select predicted structure

  [B] Show BEST matches
  [C] Include predicted structures without matches

  [N] Proceed to the next locus
  [P] Proceed to the previous locus
  [J] Jump to a selected locus

  [H] Hide a selected predictor

  [X] Exit the visualization tool

Selection:
```

\
\
Providing a number to the interactive prompt will open the corresponding alignment between the predicted 3D structure and its structural homolog in [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html):

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/ECU03_1140-m4_3kdf_B.png">  

\
\
Selecting [M] will open a submenu to select a 3D structure and view it in [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html)   (color-coded by per-residue confidence scores if available):

```
Selection: M


	Which of the following predictors would you like to see viewable structural predictions for?

		ALPHAFOLD
		RAPTORX
		ROSETTAFOLD

	Selection: ALPHAFOLD


		Which of the following models would you like to visualize?

			ECU03_1140-m1.pdb
			ECU03_1140-m2.pdb
			ECU03_1140-m3.pdb
			ECU03_1140-m4.pdb
			ECU03_1140-m5.pdb

		Selection: ECU03_1140-m1.pdb

```

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/ECU03_1140-m4.png">  

#### Interpreting the results
> Using the approach above, we were able to identity the ECU03_1140 protein from *Encephalitozoon cuniculi* as Stn1. In yeast, Stn1 is part of the Cdc13-Stn1-Ten1 complex involved in telomere protection and maintenance. Stn1 is a telomere-specific structural homolog of replication protein A 32 (RPA32), which has been identified previously in *E. cuniculi* based on sequence homology, and which shows up in the best matches based on structural homology. This is a good example of why manual curation is recommended as assigning a function based solely on the top structural homolog could lead to an erroneous conclusion.

</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: The 3DFI pipeline process in detail</i></b></summary>

### The 3DFI pipeline process in detail
This section details the behaviour of each independent script used by the run_3DFI.pl master script and is split into the following subsections:
- [Preparing FASTA files](https://github.com/PombertLab/3DFI#preparing-fasta-files)
- [3D structure prediction](https://github.com/PombertLab/3DFI#3D-structure-prediction)
- [Structural homology searches](https://github.com/PombertLab/3DFI#structural-homology-searches)
- [Structural alignment and visualization](https://github.com/PombertLab/3DFI#structural-alignment-and-visualization)

#### Preparing FASTA files
Single FASTA files (one sequence per file) are expected by most predictors and can be created from a MULTIFASTA file with [split_Fasta.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/split_Fasta.pl):

```Bash
## Creating a working directory for 3DFI:
export RESULTS=~/Results_3DFI
export FSAOUT=$RESULTS/FASTA
mkdir -p $RESULTS

## Running split_Fasta.pl on provided examples:
split_Fasta.pl \
   -f $TDFI_HOME/Examples/FASTA/*.fasta \
   -o $FSAOUT
```

By default, single FASTA files will be named after the word (\w+) characters following the > in the FASTA header of each sequence. This can be changed to nonspace characters (\S+) with the -r option. If so, special characters (e.g. |, \\, @) will be substituted by underscores to prevent issues with filenames.

If desired, single sequences can further be subdivided into smaller segments using sliding windows. This can be useful for very large proteins, which can be difficult to fold computationally.

<details open>
  <summary>Options for split_Fasta.pl are:</summary>

```Bash
## General
-f (--fasta)	FASTA input file(s) (supports .gz gzipped files)
-o (--output)	Output directory [Default: Split_Fasta]
-e (--ext)	Desired file extension [Default: fasta]
-v (--verbose)	Adds verbosity

## Fasta header parsing
-r (--regex)	word (\w+) or nonspace (\S+) [Default: word]

## Sliding window options
-w (--window)	Split individual fasta sequences into fragments using sliding windows [Default: off]
-s (--size)	Size of the the sliding window [Default: 250 (aa)]
-l (--overlap)	Sliding window overlap [Default: 100 (aa)]
```
</details>

#### 3D structure prediction
##### AlphaFold2 - deep-learning-based protein structure modeling
The [alphafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/alphafold.pl) script is a Perl wrapper that enables running AlphaFold2 in batch mode. To run alphafold.pl on multiple fasta files, type:

```bash
## Creating working directories for 3DFI / AlphaFold2:
export RESULTS=~/Results_3DFI
export FOLDING=$RESULTS/Folding
export AF=$FOLDING/ALPHAFOLD_3D
mkdir -p $RESULTS $FOLDING $AF

## Running AlphaFold on provided examples:
alphafold.pl \
   -f $TDFI_HOME/Examples/FASTA/*.fasta \
   -o $AF
```

<details open>
  <summary>Options for alphafold.pl are:</summary>

```
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-d (--docker)		Docker image name [Default: alphafold_3dfi]
-m (--max_date)		--max_template_date option (YYYY-MM-DD) from AlphaFold2 [Default: current date]
-p (--preset)		Alphafold preset: full_dbs, reduced_dbs or casp14 [Default: full_dbs]
-g (--gpu_dev)		List of GPU devices to use: e.g. all; 0,1; 0,1,2,3 [Default: all]
-n (--no_gpu)		Turns off GPU acceleration
-ah (--alpha_home)	AlphaFold2 installation directory [Default: $ALPHAFOLD_HOME]
-ad (--alpha_db)	AlphaFold2 databases location [Default: $TDFI_DB/ALPHAFOLD]
```
</details>

Folding results per protein will be located in corresponding subdirectories. Results with AlphaFold will contain PDB files for unrelaxed models (*i.e.* predicted as is before relaxation), relaxed models, and ranked models from best (0) to worst (4). Each subdirectory should look like this:

```bash
ls -l $AF/ECU03_1140/

total 47388
-rw-r--r--. 1 jpombert jpombert 1072239 Sep 15 12:36 features.pkl
drwxr-xr-x. 1 jpombert jpombert     134 Sep 15 12:36 msas
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_0.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_1.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_2.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_3.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 ranked_4.pdb
-rw-r--r--. 1 jpombert jpombert     330 Sep 15 12:46 ranking_debug.json
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:39 relaxed_model_1.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:41 relaxed_model_2.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:43 relaxed_model_3.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:45 relaxed_model_4.pdb
-rw-r--r--. 1 jpombert jpombert  149210 Sep 15 12:46 relaxed_model_5.pdb
-rw-r--r--. 1 jpombert jpombert 9084306 Sep 15 12:38 result_model_1.pkl
-rw-r--r--. 1 jpombert jpombert 9084306 Sep 15 12:41 result_model_2.pkl
-rw-r--r--. 1 jpombert jpombert 9127362 Sep 15 12:42 result_model_3.pkl
-rw-r--r--. 1 jpombert jpombert 9127362 Sep 15 12:44 result_model_4.pkl
-rw-r--r--. 1 jpombert jpombert 9127362 Sep 15 12:46 result_model_5.pkl
-rw-r--r--. 1 jpombert jpombert     772 Sep 15 12:46 timings.json
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:38 unrelaxed_model_1.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:41 unrelaxed_model_2.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:42 unrelaxed_model_3.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:44 unrelaxed_model_4.pdb
-rw-r--r--. 1 jpombert jpombert   73112 Sep 15 12:46 unrelaxed_model_5.pdb
```

The script [parse_af_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/parse_af_results.pl) can be used to recurse through the subdirectories and copy the PDB model(s) with more descriptive names including the prefixes of the FASTA files to a selected location. To use [parse_af_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/parse_af_results.pl),  type:

```bash
export AFPARSED=$FOLDING/ALPHAFOLD_3D_Parsed

parse_af_results.pl \
  -a $AF \
  -o $AFPARSED \
  -p k \
  -t 5 \
  -s
```

<details open>
  <summary>Options for parse_af_results.pl are:</summary>

```
-a (--afdir)	AlphaFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	ranked (k), relaxed (r), unrelaxed (u), all (a) [Default: k]
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-s (--standard)	Uses standardized model names (-m1 to -m5) instead of -r0 to -r4 for ranked PDB files 
-v (--verbose)	Adds verbosity
```
</details>

##### RoseTTAFold - deep-learning-based protein structure modeling
The [rosettafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/rosettafold.pl) script is a Perl wrapper that enables running the [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) run_e2e_ver.sh / run_pyrosetta_ver.sh scripts in batch mode. To run rosettafold.pl on multiple fasta files, type:

```bash
## Creating working directories for 3DFI / RoseTTAFold:
export RESULTS=~/Results_3DFI
export FOLDING=$RESULTS/Folding
export RF=$FOLDING/ROSETTAFOLD_3D
mkdir -p $RESULTS $FOLDING $RF

## Running RoseTTAFold on provided examples:
rosettafold.pl \
   -f $TDFI_HOME/Examples/FASTA/*.fasta \
   -o $RF
```

<details open>
  <summary>Options for rosettafold.pl are:</summary>

```
-f (--fasta)	FASTA files to fold
-o (--outdir)	Output directory
-t (--type)	Folding type: pyrosetta (py) or end-to-end (e2e)  [Default: e2e]
-r (--rosetta)	RoseTTAFold installation directory ## if not set in $ROSETTAFOLD_HOME
```
</details>

Note that the e2e folding option is constrained by video RAM and requires a CUDA-enabled GPU with more than 8 Gb of RAM to tackle large proteins (a video card with at least 24 Gb of RAM is recommended). If out of memory, the 'RuntimeError: CUDA out of memory' will appear in the log/network.stderr file and the .pdb file will not be generated. The pyrosetta folding option is slower (CPU-bound) but not constrained by video RAM.

Folding results per protein will be located in corresponding subdirectories. Results with the e2e option should look like below, with the model generated named t000_.e2e.pdb:

```bash
ls -l  $RF/ECU03_1140/
total 4248
drwxr-xr-x. 1 jpombert jpombert     508 Sep 15 14:12 hhblits
drwxr-xr-x. 1 jpombert jpombert     232 Sep 15 14:14 log
-rw-r--r--. 1 jpombert jpombert  914410 Sep 15 14:14 t000_.atab
-rw-r--r--. 1 jpombert jpombert   23517 Sep 15 14:15 t000_.e2e_init.pdb
-rw-r--r--. 1 jpombert jpombert 2877483 Sep 15 14:15 t000_.e2e.npz
-rw-r--r--. 1 jpombert jpombert   31356 Sep 15 14:15 t000_.e2e.pdb
-rw-r--r--. 1 jpombert jpombert  481512 Sep 15 14:14 t000_.hhr
-rw-r--r--. 1 jpombert jpombert    3643 Sep 15 14:12 t000_.msa0.a3m
-rw-r--r--. 1 jpombert jpombert    3897 Sep 15 14:12 t000_.msa0.ss2.a3m
-rw-r--r--. 1 jpombert jpombert     254 Sep 15 14:12 t000_.ss2
``` 

Results with the pyrosetta option should look like below, with the models generated (5 in total) located in the model/ subfolder:

```bash
ls -l $RF/ECU03_1140/
total 4284
drwxrwxr-x 1 jpombert jpombert     508 Sep 15 15:28 hhblits
drwxrwxr-x 1 jpombert jpombert     388 Sep 15 15:45 log
drwxrwxr-x 1 jpombert jpombert     310 Sep 15 15:45 model
-rw-rw-r-- 1 jpombert jpombert    4125 Sep 15 15:29 parallel.fold.list
drwxrwxr-x 1 jpombert jpombert    1020 Sep 15 15:45 pdb-3track
-rw-rw-r-- 1 jpombert jpombert 2959088 Sep 15 15:29 t000_.3track.npz
-rw-rw-r-- 1 jpombert jpombert  914410 Sep 15 15:29 t000_.atab
-rw-rw-r-- 1 jpombert jpombert  481760 Sep 15 15:29 t000_.hhr
-rw-rw-r-- 1 jpombert jpombert    3941 Sep 15 15:28 t000_.msa0.a3m
-rw-rw-r-- 1 jpombert jpombert    4195 Sep 15 15:28 t000_.msa0.ss2.a3m
-rw-rw-r-- 1 jpombert jpombert     254 Sep 15 15:28 t000_.ss2
```

The script [parse_rf_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/parse_rf_results.pl) can be used to recurse through the subdirectories and copy the PDB model(s) with more descriptive names including the prefixes of the FASTA files to a selected location. To use [parse_rf_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/parse_rf_results.pl),  type:

```bash
parse_rf_results.pl \
  -r $RF \
  -o $FOLDING/ROSETTAFOLD_3D_Parsed \
  -p e2e
```

<details open>
  <summary>Options for parse_rf_results.pl are:</summary>

```
-r (--rfdir)	RoseTTAFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	PDB type: pyrosetta (py) or end-to-end (e2e) [Default: e2e]
-t (--top)	Top X number of pdb files to keep for pyrosetta PDBs, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
```
</details>

##### RaptorX - template-based protein structure modeling
To predict 3D structures with [RaptorX](http://raptorx.uchicago.edu/) using [raptorx.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx.pl):

```bash
## Creating working directories for 3DFI / RaptorX:
export RESULTS=~/Results_3DFI
export FOLDING=$RESULTS/Folding
export RX=$FOLDING/RAPTORX_3D
mkdir -p $RESULTS $FOLDING $RX

## Running RaptorX on provided examples with 10 CPUs and folding against the top 5 templates:
raptorx.pl \
   -t 10 \
   -k 5 \
   -i $TDFI_HOME/Examples/FASTA \
   -o $RX
```

<details open>
  <summary>Options for raptorx.pl are:</summary>

```
-t (--threads)	Number of threads to use [Default: 10]
-i (--input)	Folder containing fasta files
-o (--output)	Output folder
-k (--TopK)	Number of top template(s) to use per protein for model building [Default: 1]
-m (--modeller)	MODELLER binary name [Default: mod10.1] ## Use absolute or relative path if not set in $PATH
```
</details>

NOTES:
- RaptorX expects a PYTHONHOME environment variable but runs fine without it. The following warning message can be safely ignored (silencing it by setting up the PYTHONHOME environment variable could create issues with other applications).
```renamed env vars for consistencyindependent libraries <prefix>
Could not find platform dependent libraries <exec_prefix>
Consider setting $PYTHONHOME to <prefix>[:<exec_prefix>]
```
- The import site warning message below can also be safely ignored:
```
'import site' failed; use -v for traceback
```

#### Structural homology searches
##### Downloading PDB files from RCSB
PDB files from the [Protein Data Bank](https://www.rcsb.org/) can be downloaded directly from its website. Detailed instructions are provided [here](https://www.wwpdb.org/ftp/pdb-ftp-sites). Because of the large size of this dataset, downloading it using [rsync](https://rsync.samba.org/) is recommended. This can be done with [update_PDB.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/update_PDB.pl) as follows:

```bash
## Setting up RCSB PDB database location:
export TDFI_DB=/media/FatCat/databases/3DFI
export RCSB_PDB=$TDFI_DB/RCSB_PDB/

## Downloading the RCSB PDB database:
update_PDB.pl \
  -o $RCSB_PDB \
  -n 15
```

<details open>
  <summary>Options for update_PDB.pl are:</summary>

```
-o (--outdir)	PDB output directory [Default: PDB]
-n (--nice)	Defines niceness (adjusts scheduling priority)
```
</details>

##### Creating a list of PDB titles
To create a tab-delimited list of PDB entries and their titles and chains from the downloaded PDB gzipped files (pdb*.ent.gz), we can use [PDB_headers.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/PDB_headers.pl) (requires [PerlIO::gzip](https://metacpan.org/pod/PerlIO::gzip)):

```Bash
## Setting up 3DFI results location:
export TDFI_DB=/media/FatCat/databases/3DFI

## Running a list of titles and chains from PDB files
PDB_headers.pl \
   -p $RCSB_PDB \
   -o $TDFI_DB/RCSB_PDB_titles.tsv
```

<details open>
  <summary>Options for PDB_headers.pl are:</summary>

```
-p (--pdb)	Directory containing PDB files downloaded from RCSB PDB/PDBe (gzipped)
-o (--output)	Output file in tsv format
-v (--verbose)	Prints progess every X file [Default: 1000]
```
</details>

The list created should look like this:

```
5tzz	TITLE	CRYSTAL STRUCTURE OF HUMAN PHOSPHODIESTERASE 2A IN COMPLEX WITH 1-[(3-BROMO-4-FLUOROPHENYL)CARBONYL]-3,3-DIFLUORO-5-{5-METHYL-[1,2, 4]TRIAZOLO[1,5-A]PYRIMIDIN-7-YL}PIPERIDINE 
5tzz	A	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
5tzz	B	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
5tzz	C	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
5tzz	D	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
4tza	TITLE	TGP, AN EXTREMELY THERMOSTABLE GREEN FLUORESCENT PROTEIN CREATED BY STRUCTURE-GUIDED SURFACE ENGINEERING 
4tza	C	FLUORESCENT PROTEIN
4tza	A	FLUORESCENT PROTEIN
4tza	B	FLUORESCENT PROTEIN
4tza	D	FLUORESCENT PROTEIN
4tz3	TITLE	ENSEMBLE REFINEMENT OF THE E502A VARIANT OF SACTELAM55A FROM STREPTOMYCES SP. SIREXAA-E IN COMPLEX WITH LAMINARITETRAOSE 
4tz3	A	PUTATIVE SECRETED PROTEIN
5tzw	TITLE	CRYSTAL STRUCTURE OF HUMAN PHOSPHODIESTERASE 2A IN COMPLEX WITH 1-[(3,4-DIFLUOROPHENYL)CARBONYL]-3,3-DIFLUORO-5-{5-METHYL-[1,2, 4]TRIAZOLO[1,5-A]PYRIMIDIN-7-YL}PIPERIDINE 
5tzw	A	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
5tzw	B	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
5tzw	C	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
5tzw	D	CGMP-DEPENDENT 3',5'-CYCLIC PHOSPHODIESTERASE
```

##### Creating or updating a GESAMT database
Before performing structural homology searches with GESAMT (from the [CCP4](https://www.ccp4.ac.uk/) package), we should first create an archive to speed up the searches. We can also update the archive later as sequences are added (for example after the RCSB PDB files are updated with rsync). GESAMT archives can be created/updated with [run_GESAMT.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/run_GESAMT.pl):

```Bash
## Creating environment variables pointing to our GESAMT archive:
export TDFI_DB=/media/FatCat/databases/3DFI
export GESAMT_ARCHIVE=$TDFI_DB/RCSB_GESAMT

## To create a GESAMT archive:
run_GESAMT.pl \
   -cpu 10 \
   -make \
   -arch $GESAMT_ARCHIVE \
   -pdb $RCSB_PDB

## To update a GESAMT archive:
run_GESAMT.pl \
   -cpu 10 \
   -update \
   -arch $GESAMT_ARCHIVE \
   -pdb $RCSB_PDB
```

<details open>
  <summary>Options to create/update a GESAMT archive with run_GESAMT.pl are:</summary>

```
-c (--cpu)	CPU threads [Default: 10]
-a (--arch)	GESAMT archive location [Default: ./]
-m (--make)	Create a GESAMT archive
-u (--update)	Update existing archive
-p (--pdb)	Folder containing RCSB PDB files to archive
```
</details>

##### Structural homology searches with GESAMT
Structural homology searches with GESAMT can also be performed with [run_GESAMT.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/run_GESAMT.pl):

```Bash
## Creating a working directory for GESAMT:
export RESULTS=~/Results_3DFI
export GSMT=$RESULTS/Homology/GESAMT
mkdir -p $RESULTS $GSMT

## Performing structural homology searches with GESAMT:
run_GESAMT.pl \
   -cpu 10 \
   -query \
   -arch $GESAMT_ARCHIVE \
   -input $TDFI_HOME/Examples/Results_3DFI/Folding/ALPHAFOLD_3D_Parsed/*.pdb \
   -o $GSMT \
   -mode normal
```

<details open>
  <summary>Options to query a GESAMT archive with run_GESAMT.pl are:</summary>

```
-c (--cpu)	CPU threads [Default: 10]
-a (--arch)	GESAMT archive location [Default: ./]
-q (--query)	Query a GESAMT archive
-i (--input)	PDF files to query
-o (--outdir)	Output directory [Default: ./]
-d (--mode)	Query mode: normal of high [Default: normal]
-z (--gzip)	Compress output files [Default: off]
```
</details>

Results of GESAMT homology searches will be found in the \*.gesamt files generated. Content of these files should look like:
```
#  Hit   PDB  Chain  Q-score  r.m.s.d     Seq.  Nalign  nRes    File
#  No.   code   Id                         Id.                  name
     1   5V7K   A     0.5610   1.9652   0.1262    214    255   pdb5v7k.ent.gz
     2   5T9D   C     0.5607   2.0399   0.1268    213    247   pdb5t9d.ent.gz
     3   6CX4   A     0.5590   1.9153   0.1226    212    255   pdb6cx4.ent.gz
     4   1PLR   A     0.5551   1.9919   0.1302    215    258   pdb1plr.ent.gz
```

##### Parsing the output of GESAMT searches
To add definitions/products to the PDB matches found with GESAMT, we can use the list generated by [PDB_headers.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/PDB_headers.pl) together with [descriptive_GESAMT_matches.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/descriptive_GESAMT_matches.pl):

```Bash
descriptive_GESAMT_matches.pl \
   -r $TDFI_DB/RCSB_PDB_titles.tsv \
   -m $GSMT/*.gesamt.gz \
   -q 0.3 \
   -b 5 \
   -o $RESULTS/ALPHAFOLD_GESAMT_per_model.matches
```

<details open>
  <summary>Options for descriptive_GESAMT_matches.pl are:</summary>

```
-r (--rcsb)	Tab-delimited list of RCSB structures and their titles ## see PDB_headers.pl 
-p (--pfam)	Tab-delimited list of PFAM structures and their titles (http://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz)
-m (--matches)	Results from GESAMT searches ## Supports GZIPPEd files; see run_GESAMT.pl
-q (--qscore)	Q-score cut-off [Default: 0.3]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: Gesamt.matches]
-l (--log)	Error log file [Default: descriptive_matches.err]
-n (--nobar)	Turn off the progress bar
-x (--regex)	Regex to parse filenames: word (\w+) or nonspace (\S+) [Default: nonspace]
```
</details>

The concatenated list generated should look like:
```
### ECU03_1140-m1; Query mode = normal
ECU03_1140-m1	1	3KDF	D	0.6666	1.6532	0.1545	110	119	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m1	2	1QUQ	C	0.6543	1.7185	0.1545	110	119	pdb1quq.ent.gz	PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
ECU03_1140-m1	3	2PQA	A	0.6507	1.6714	0.1504	113	128	pdb2pqa.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m1	4	3KDF	B	0.6479	1.7816	0.1545	110	118	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m1	5	4GNX	B	0.6460	1.6761	0.1182	110	122	pdb4gnx.ent.gz	PUTATIVE UNCHARACTERIZED PROTEIN
### ECU03_1140-m2; Query mode = normal
ECU03_1140-m2	1	3KDF	D	0.6744	1.6116	0.1545	110	119	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m2	2	1QUQ	C	0.6613	1.6815	0.1545	110	119	pdb1quq.ent.gz	PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
ECU03_1140-m2	3	2PQA	A	0.6578	1.6328	0.1593	113	128	pdb2pqa.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m2	4	4GNX	B	0.6523	1.6419	0.1182	110	122	pdb4gnx.ent.gz	PUTATIVE UNCHARACTERIZED PROTEIN
ECU03_1140-m2	5	4GOP	B	0.6513	1.6472	0.1182	110	122	pdb4gop.ent.gz	PUTATIVE UNCHARACTERIZED PROTEIN
### ECU03_1140-m3; Query mode = normal
ECU03_1140-m3	1	3KDF	D	0.6705	1.6324	0.1545	110	119	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m3	2	1QUQ	C	0.6591	1.6930	0.1545	110	119	pdb1quq.ent.gz	PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
ECU03_1140-m3	3	2PQA	A	0.6552	1.6470	0.1593	113	128	pdb2pqa.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
ECU03_1140-m3	4	4GNX	B	0.6503	1.6531	0.1182	110	122	pdb4gnx.ent.gz	PUTATIVE UNCHARACTERIZED PROTEIN
ECU03_1140-m3	5	3KDF	B	0.6496	1.7729	0.1545	110	118	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
```

##### Parsing the output of descriptive_GESAMT_matches.pl per protein accross all models, from best Q-score to worst
Structural matches obtained from all protein stucture predictors can be parsed with [parse_all_models_by_Q.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/parse_all_models_by_Q.pl). To summarize these matches with parse_all_models_by_Q.pl:

```Bash
parse_all_models_by_Q.pl \
  -m *_GESAMT_per_model.matches \
  -o All_GESAMT_matches_per_protein.tsv
```

<details open>
  <summary>Options for parse_all_models_by_Q.pl are:</summary>

```
-m (--matches)	*.GESAMT.matches generated by descriptive_GESAMT_matches.pl
-o (--out)	Output file in TSV format [Default: All_GESAMT_matches_per_protein.tsv]
-x (--max)	Max number of distinct RCSB/chain hits to keep [Default: 50]
-r (--redun)	Keep all entries for redundant RCSB chains [Default: off]
-w (--word)	Use word regular expression (\w+) to capture locus tag [Default: off]
```
</details>

#### Structural alignment and visualization
##### About alignment and visualization
Visually inspecting the predicted 3D structure of a protein is an important step in determing the validity of any identified structural homolog. Though a .pdb file may be obtained from a protein structure prediction tool, the quality of the fold may be low. Alternatively, though GESAMT may return a structural homolog with a reasonable Q-score, the quality of the alignment may be low. A low fold/alignment-quality can result in both false-positives (finding a structural homolog when one doesn't exist) and false-negatives (not finding a structural homolog when one exists). Visually inspecting protein structures and structural homolog alignments is an easy way to prevent these outcomes. This can be done with the excellent [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/) molecular visualization program.

Examples:
- A [good result](https://github.com/PombertLab/3DFI/blob/master/Images/Good_Match.png), in which both the folding and the alignment are good.
- A [false-negative](https://github.com/PombertLab/3DFI/blob/master/Images/Bad_Predicted_Fold.png), where the quality of the protein folding is low, resulting in a failure to find a structural homolog.
- A [false-positive](https://github.com/PombertLab/3DFI/blob/master/Images/Bad_Match.png), where the quality of the fold is high, but the alignment-quality is low and a pseudo-structural homolog is found.

##### Aligning protein structures and inspecting alignments with ChimeraX
To prepare visualizations for inspection, we can use [prepare_visualizations.pl](https://github.com/PombertLab/3DFI/blob/master/Visualization/prepare_visualizations.pl) to automatically align predicted proteins with their GESAMT-determined structural homologs. These alignments are performed with [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/) via its API.

```bash
## Creating shortcut to results directory
export RESULTS=~/Results_3DFI
export RCSB_PDB=$TDFI_DB/RCSB_PDB/

## Preparing data for visualization:
prepare_visualizations.pl \
    -g $TDFI_HOME/Examples/Results_3DFI/Homology/GESAMT/ALPHAFOLD_GESAMT_per_model.matches \
    -p $TDFI_HOME/Examples/Results_3DFI/Folding/ALPHAFOLD_3D_Parsed/ \
    -r $RCSB_PDB \
    -o $RESULTS/Visualization
```

<details open>
  <summary>Options for prepare_visualizations.pl are:</summary>

```
-g (--gesamt)	GESAMT descriptive matches ## generated by descriptive_matches.pl
-p (--pred)	Absolute path to predicted .pdb files
-r (--rcsb)	Absolute path to RCSB .ent.gz files
-k (--keep)	Keep unzipped RCSB .ent files
-o (--outdir)	Output directory for ChimeraX sessions [Default: ./3D_Visualizations]
```
</details>

To inspect the 3D structures, we can run [run_visualizations.pl](https://github.com/PombertLab/3DFI/blob/master/run_visualizations.pl) on the 3DFI results directory:
```bash
run_visualizations.pl \
    -r $RESULTS
```

The output should result in something similar to the following:
```
### ECU03_1140 has 15 matches. ###

  - Currently in best match mode 
  - Viewing only proteins with matches

|=============================================================================================================================|
  Selection  Q-Score     Predicted Structure     PDB-File => Chain     Structural Homolog Description
|=============================================================================================================================|
      1       0.822       RAPTORX => Model 4         3KDF => B         REPLICATION PROTEIN A 32 KDA SUBUNIT
      2       0.785       RAPTORX => Model 4         1QUQ => A         PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
      3       0.785       RAPTORX => Model 4         3KDF => D         REPLICATION PROTEIN A 32 KDA SUBUNIT
      4       0.784       RAPTORX => Model 4         1L1O => E         REPLICATION PROTEIN A 32 KDA SUBUNIT
      5       0.782       RAPTORX => Model 4         2PI2 => D         REPLICATION PROTEIN A 32 KDA SUBUNIT
|=============================================================================================================================|


Selectable Options:

  [1-5] Open corresponding match file
  [M] To select predicted structure

  [A] Show ALL matches
  [C] Include predicted structures without matches

  [N] Proceed to the next locus
  [P] Proceed to the previous locus
  [J] Jump to a selected locus

  [H] Hide a selected predictor

  [X] Exit the visualization tool

Selection: 

```

In this example, selecting [M] will open the visualization of the predicted 3D structure with [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html):

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/Just_PDB.png">

The structure can then be interacted with using ChimeraX [commands](https://www.rbvi.ucsf.edu/chimerax/docs/user/index.html). For example, the structure can be colored with a rainbow scheme to better distinguish between structural domains:

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/Just_PDB_rainbow.png">

Alternatively, selecting [1-5] will open the visualization of the alignment of the predicted 3D structure with its selected structural homolog:

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/With_Alignment.png">

##### Coloring AlphaFold2 or RoseTTAFold predictions per confidence scores
[AlphaFold2](https://github.com/deepmind/alphafold) and [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) add per-residue confidence scores to the B-factor [columns](https://www.cgl.ucsf.edu/chimera/docs/UsersGuide/tutorials/pdbintro.html) of the PDB files they generate. AlphaFold adds pLDDT (predicted lDDT-Cα) values ranging from 0 to 100 while RoseTTAFold adds CA-lDDT values from 0 to 1 when using its end-to-end implementation (its PyRosetta version uses estimated CA RMS errors instead).

To color the AlphaFold and RoseTTAFold (end-to-end) stuctures similarly to the scheme used in the DeepMind/EBI [AlphaFold Protein Structure Database](https://alphafold.ebi.ac.uk/), we can use the following ChimeraX command:
```Bash
## AlphaFold
color byattribute bfactor palette orangered:yellow:cyan:blue range 50,100

## RoseTTAFold
color byattribute bfactor palette orangered:yellow:cyan:blue range 0.5,1
```
<img src="https://github.com/PombertLab/3DFI/blob/master/Images/bfactor.png">

We can also add a color legend by appending 'key true' to the Chimerax [color byattribute](https://www.cgl.ucsf.edu/chimerax/docs/user/commands/color.html#byattribute) command. The added legend can be adjusted with the interactive 'Color key' graphical tool (launched automatically):
```Bash
## AlphaFold
color byattribute bfactor palette orangered:yellow:cyan:blue range 50,100 key true

## RoseTTAFold
color byattribute bfactor palette orangered:yellow:cyan:blue range 0.5,1 key true
```
<img src="https://github.com/PombertLab/3DFI/blob/master/Images/bfactor_key.png">

Alternatively, we can also set the legend using the Chimerax [key](https://www.cgl.ucsf.edu/chimerax/docs/user/commands/key.html) command. For example, we can set it to the right of the molecule with:
```
key pos 0.85,0.2 size 0.04,0.6 justification left labelOffset 5

## In the above:
pos x,y => x and y coordinates
size w,h => width and height
```
<img src="https://github.com/PombertLab/3DFI/blob/master/Images/bfactor_key_cmd.png">


Note that to save an image with a transparent background in Chimerax (see [manual](https://www.cgl.ucsf.edu/chimerax/docs/user/commands/save.html)), we can use:
```
save ~/bfactor.png transparentBackground True
```
</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: Miscellaneous</i></b></summary>

## Miscellaneous
##### Useful scripts
###### Splitting PDB files
RCSB PDB files can be split per chain with [split_PDB.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/split_PDB.pl):
```
split_PDB.pl \
   -p files.pdb \
   -o output_folder \
   -e pdb
```

<details open>
  <summary>Options for split_PDB.pl are:</summary>

```
-p (--pdb)	PDB input file (supports gzipped files)
-o (--output)	Output directory. If blank, will create one folder per PDB file based on file prefix
-e (--ext)	Desired file extension [Default: pdb]
```
</details>

###### Renaming files
Files can be renamed using regular expressions with [rename_files.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/rename_files.pl):
```
rename_files.pl \
   -o 'i{0,1}-t26_1-p1' \
   -n '' \
   -f *.fasta
```

<details open>
  <summary>Options for rename_files.pl are:</summary>

```
-o (--old)	Old pattern/regular expression to replace with new pattern
-n (--new)	New pattern to replace with; defaults to blank [Default: '']
-f (--files)	Files to rename
```
</details>

##### Alternate predictors 
This section refers to predictors that are no longer maintained / not yet supported. Code is available in [3DFI/prediction](https://github.com/PombertLab/3DFI/tree/master/Prediction). 

###### trRosetta - deep-learning-based protein structure modeling
To perform 3D structure predictions locally with [trRosetta](https://github.com/gjoni/trRosetta), [HH-suite3](https://github.com/soedinglab/hh-suite), [tensorflow](https://www.tensorflow.org/) version 1.15 and [PyRosetta](http://www.pyrosetta.org/) must be installed. A database for HHsuite3's hhblits, such as [Uniclust](https://uniclust.mmseqs.com/), should also be installed. Note that hhblits databases should be located on a solid state disk (ideally NVME) to reduce i/o bottlenecks during homology searches.

For ease of use, [tensorflow](https://www.tensorflow.org/) 1.15 and [PyRosetta](http://www.pyrosetta.org/) can be installed in a conda environment. For more detail, see [trRosetta_installation_notes.sh](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/trRosetta_installation_notes.sh).

###### Tensorflow 1.15 in conda
To install tensorflow with GPU in conda:

```Bash
## The files can eat through GPU VRAM very quickly. 8 Gb is usually insufficient.
conda create -n tfgpu python=3.7
conda activate tfgpu
pip install tensorflow-gpu==1.15
pip install numpy==1.19.5
conda install cudatoolkit==10.0.130
conda install cudnn==7.6.5
```

To install tensorflow with CPU in conda:

```Bash
conda create -n tfcpu python=3.7
conda activate tfcpu
pip install tensorflow-cpu==1.15
pip install numpy==1.19.5
```

###### Running trRosetta
Running [trRosetta](https://github.com/gjoni/trRosetta) involves 3 main steps: 1) searches with [HHsuite3](https://github.com/soedinglab/hh-suite)'s hhblits to generate alignments (.a3m); 2) prediction of protein inter-residue geometries (.npz) with [trRosetta](https://github.com/gjoni/trRosetta)'s predict.py; and 3) prediction of 3D structures (.pdb) with trRosetta.py and [PyRosetta](http://www.pyrosetta.org/). Performing these predictions on several proteins can be automated with 3DFI scripts. 

```bash
## Setting up trRosetta installation directories as environment variables:
export TRROSETTA_HOME=/opt/trRosetta
export TRROSETTA_SCRIPTS=$TRROSETTA_HOME/trRosetta_scripts
Aligning strucutures and inspecting 
## Creating a working directory for trRosetta:
export RESULTS=~/Results_3DFI
export TR=$RESULTS/TRROSETTA_3D
mkdir -p $RESULTS $TR
```

1. To convert FASTA sequences to single string FASTA sequences with [fasta_oneliner.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/fasta_oneliner.pl), type:

```Bash
$TR_3DFI/fasta_oneliner.pl \
   -f $TDFI/Examples/FASTA/*.fasta \
   -o $TR/FASTA_OL
```

<details open>
  <summary>Options for fasta_oneliner.pl are:</summary>

```
-f (--fasta)    FASTA files to convert
-o (--output)   Output folder
```
</details>

2. To run hhblits searches with [run_hhblits.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/run_hhblits.pl), type:

```Bash
## Setting Uniclust database (https://uniclust.mmseqs.com/) location:
export UNICLUST=/media/FatCat/databases/UniRef30_2020_06

## Running hhblits on multiple evalues independently:
$TR_3DFI/run_hhblits.pl \
   -t 10 \
   -f $TR/FASTA_OL/ \
   -o $TR/HHBLITS/ \
   -d $UNICLUST/UniRef30_2020_06 \
   -e 1e-40 1e-10 1e-03 1e+01

## Running hhblits on evalues sequentially, from stricter to more permissive:
$TR_3DFI/run_hhblits.pl \
   -t 10 \
   -f $TR/FASTA_OL/ \
   -o $TR/HHBLITS/ \
   -d $UNICLUST/UniRef30_2020_06 \
   -s \
   -se 1e-70 1e-50 1e-30 1e-10 1e-06 1e-04 1e+01
```

<details open>
  <summary>Options for run_hhblits.pl are:</summary>

```
-t (--threads)	    Number of threads to use [Default: 10]
-f (--fasta)	    Folder containing fasta files
-o (--output)	    Output folder
-d (--database)     Uniclust database to query
-v (--verbosity)    hhblits verbosity; 0, 1 or 2 [Default: 2]

## E-value options
-e (--evalues)      Desired evalue(s) to query independently
-s (--seq_it)       Iterates sequentially through evalues
-se (--seq_ev)      Evalues to iterate through sequentially [Default:
                    1e-70 1e-60 1e-50 1e-40 1e-30 1e-20 1e-10 1e-08 1e-06 1e-04 1e+01 ]
-ne (--num_it)      # of hhblits iteration per evalue (-e) [Default: 3]
-ns (--num_sq)      # of hhblits iteration per sequential evalue (-s) [Default: 1] 
```
</details>

3. To create .npz files containing inter-residue geometries with [create_npz.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/create_npz.pl), type:
```Bash
## activate conda environment tfcpu or tfgpu
conda activate tfcpu

## Creating npz files:
$TR_3DFI/create_npz.pl \
   -a $TR/HHBLITS/*.a3m \
   -o $TR/NPZ/
```

<details open>
  <summary>Options for create_npz.pl are:</summary>

```
-a (--a3m)		.a3m files generated by hhblits
-o (--output)		Output folder [Default: ./]
-t (--trrosetta)	trRosetta installation directory (TRROSETTA_HOME)
-m (--model)		trRosetta model directory [Default: model2019_07]
```
</details>

4. To generate .pdb files containing 3D models from the .npz files with [create_pdb.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/create_pdb.pl), type:

```Bash
## activate conda environment tfcpu or tfgpu
conda activate tfcpu

## Creating PDB files
$TR_3DFI/create_pdb.pl \
   -c 10 \
   -n $TR/NPZ/ \
   -o $TR/PDB/ \
   -f $TR/FASTA_OL/
```

<details open>
  <summary>Options for create_pdb.pl are:</summary>

```
-c (--cpu)		Number of cpu threads to use [Default: 10] ## i.e. runs n processes in parallel
-m (--memory)		Memory available (in Gb) to threads [Default: 16] 
-n (--npz)		Folder containing .npz files
-o (--output)		Output folder [Default: ./]
-f (--fasta)		Folder containing the oneliner fasta files
-t (--trrosetta)	trRosetta installation directory (TRROSETTA_HOME)
-p (--python)		Preferred Python interpreter [Default: python]
```
</details>

5. The .pdb files thus generated contain lines that are not standard and that can prevent applications such as [PDBeFOLD](https://www.ebi.ac.uk/msd-srv/ssm/) to run on the corresponding files. We can clean up the PDB files with [sanitize_pdb.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/sanitize_pdb.pl) as follows:

```Bash
$TR_3DFI/sanitize_pdb.pl \
   -p $TR/PDB/*.pdb \
   -o $TR/PDB_clean
```

<details open>
  <summary>Options for sanitize_pdb.pl are:</summary>

```
-p (--pdb)      .pdb files generated by trRosetta
-o (--output)   Output folder
```
</details>

###### trRosetta2 - deep-learning-based protein structure modeling
How to set up [trRosetta2](https://github.com/RosettaCommons/trRosetta2) is described on its GitHub page. The [trRosetta2.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/trRosetta2.pl) script is a Perl wrapper that enables running trRosetta2 in batch mode. To simplify its use, the TRROSETTA2_HOME environment variable can be set in the shell.

```bash
## Setting up trRosetta2 installation directory as environment variable:
export TRROSETTA2_HOME=/opt/trRosetta2

## Creating a working directory for trRosetta2:
export RESULTS=~/Results_3DFI
export TR2=$RESULTS/TROS2_3D
mkdir -p $RESULTS $TR2
```

To convert FASTA sequences to single string FASTA sequences with [fasta_oneliner.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/fasta_oneliner.pl), type:

```Bash
$TR2_3DFI/fasta_oneliner.pl \
   -f $TDFI/Examples/FASTA/*.fasta \
   -o $TR2/FASTA_OL
```

<details open>
  <summary>Options for fasta_oneliner.pl are:</summary>

```
-f (--fasta)    FASTA files to convert
-o (--output)   Output folder
```
</details>

To run [trRosetta2](https://github.com/RosettaCommons/trRosetta2) in batch mode with [trRosetta2.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/trRosetta2.pl), type:
```Bash
$TR2_3DFI/trRosetta2.pl \
   -f $TR2/FASTA_OL/*.fasta \
   -o $TR2/TROS2_3D \
   -g
```

<details open>
  <summary>Options for trRosetta2.pl are:</summary>

```
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-g (--gpu)		Uses GPU acceleration (>= 16 Gb video RAM recommended); defaults to CPU otherwize
-t (--trrosetta2)	trRosetta2 installation directory
```
</details>

Results with trRosetta2 should look like below, with the models generated (5 in total) located in the model/ subfolder:

```bash
ls -l $TR2/TROS2_3D/sequence_1/
total 20212
-rw-rw-r-- 1 jpombert jpombert       0 Aug  3 15:14 DONE_iter0
-rw-rw-r-- 1 jpombert jpombert       0 Aug  3 15:32 DONE_iter1
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 14:46 hhblits
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 15:33 log
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 15:33 model
-rw-rw-r-- 1 jpombert jpombert    7170 Aug  3 14:53 parallel.list
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 15:12 pdb-msa
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 15:14 pdb-tbm
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 15:33 pdb-trRefine
drwxrwxr-x 2 jpombert jpombert    4096 Aug  3 15:18 rep_s
-rw-rw-r-- 1 jpombert jpombert  446491 Aug  3 14:46 t000_.hhr
-rw-rw-r-- 1 jpombert jpombert    3653 Aug  3 14:46 t000_.msa0.a3m
-rw-rw-r-- 1 jpombert jpombert    3907 Aug  3 14:46 t000_.msa0.ss2.a3m
-rw-rw-r-- 1 jpombert jpombert 8324016 Aug  3 14:50 t000_.msa.npz
-rw-rw-r-- 1 jpombert jpombert     254 Aug  3 14:46 t000_.ss2
-rw-rw-r-- 1 jpombert jpombert  365696 Aug  3 14:46 t000_.tape.npy
-rw-rw-r-- 1 jpombert jpombert 8561142 Aug  3 14:53 t000_.tbm.npz
-rw-rw-r-- 1 jpombert jpombert 2928017 Aug  3 15:18 t000_.trRefine.npz
-rw-rw-r-- 1 jpombert jpombert    4725 Aug  3 15:18 trRefine_fold.list
```

The script [parse_tr2_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/parse_tr2_results.pl) can be used to recurse through the subdirectories and copy the PDB model(s) with more descriptive names including the prefixes of the FASTA files to a selected location. To use [parse_tr2_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/parse_tr2_results.pl),  type:

```bash
$TR2_3DFI/parse_tr2_results.pl \
  -r $TR2/TROS2_3D \
  -o $TR2/Parsed_PDBs \
  -t 5
```

<details open>
  <summary>Options for parse_tr2_results.pl are:</summary>

```
-r (--r2dir)	trRosetta2 output directory
-o (--outdir)	Parsed output directory
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
```
</details>
</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: Funding and acknowledgments</i></b></summary>

## Funding and acknowledgments
This work was supported in part by the National Institute of Allergy and Infectious Diseases of the National Institutes of Health (award number R15AI128627) to Jean-Francois Pombert. The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institutes of Health.
</details>

<hr size="8" width="100%">  

<details open>
  <summary><b><i>Show/hide section: How to cite</i></b></summary>

## How to cite
If you use the 3DFI pipeline, please cite the 3DFI publication:

[3DFI: a pipeline to infer protein function using structural homology](https://academic.oup.com/bioinformaticsadvances/article/1/1/vbab030/6424973). **Julian AT, Mascarenhas dos Santos AC, Pombert JF.** Bioinformatics Advances, Volume 1, Issue 1, 2021, vbab030. DOI: 10.1093/bioadv/vbab030.

Please also cite the tool(s) used for protein stucture prediction (AlphaFold, RoseTTAFold and RaptorX), structural homology searches (GESAMT) and 3D visualization (ChimeraX), as needed:

[Highly accurate protein structure prediction with AlphaFold](https://pubmed.ncbi.nlm.nih.gov/34265844/). **Jumper J,** ***et al.*** Nature. 2021 Jul 15. Online ahead of print. PMID: 34265844 DOI: 10.1038/s41586-021-03819-2.

[Accurate prediction of protein structures and interactions using a three-track neural network](https://pubmed.ncbi.nlm.nih.gov/34282049/). **Baek M,** ***et al.*** Science. 2021 Jul 15; eabj8754. Online ahead of print. PMID: 34282049 DOI: 10.1126/science.abj8754

[RaptorX: exploiting structure information for protein alignment by statistical inference](https://pubmed.ncbi.nlm.nih.gov/21987485/). **Peng J, Xu J.** Proteins. 2011;79 Suppl 10:161-71. PMID: 21987485 PMCID: PMC3226909 DOI: 10.1002/prot.23175

[Enhanced fold recognition using efficient short fragment clustering](https://pubmed.ncbi.nlm.nih.gov/27882309/). **Krissinel E.** J Mol Biochem. 2012;1(2):76-85. PMID: 27882309 PMCID: PMC5117261

[UCSF ChimeraX: Structure visualization for researchers, educators, and developers](https://www.ncbi.nlm.nih.gov/pubmed/32881101). **Pettersen EF, Goddard TD, Huang CC, Meng EC, Couch GS, Croll TI, Morris JH, Ferrin TE**. Protein Sci. 2021 Jan;30(1):70-82.  PMID: 32881101 PMCID: PMC7737788 DOI: 10.1002/pro.3943

</details>

<details open>
  <summary><b><i>Show/hide section: References</i></b></summary>

## References
1) [RCSB Protein Data Bank: Architectural Advances Towards Integrated Searching and Efficient Access to Macromolecular Structure Data from the PDB Archive](https://pubmed.ncbi.nlm.nih.gov/33186584/). **Rose Y, Duarte JM, Lowe R, Segura J, Bi C, Bhikadiya C, Chen L, Rose AS, Bittrich S, Burley SK, Westbrook JD.** J Mol Biol. 2021 May 28;433(11):166704. PMID: 33186584. DOI: 10.1016/j.jmb.2020.11.003.

2) [RaptorX: exploiting structure information for protein alignment by statistical inference](https://pubmed.ncbi.nlm.nih.gov/21987485/). **Peng J, Xu J.** Proteins. 2011;79 Suppl 10:161-71. PMID: 21987485 PMCID: PMC3226909 DOI: 10.1002/prot.23175

3) [Template-based protein structure modeling using the RaptorX web server](https://pubmed.ncbi.nlm.nih.gov/22814390/). **Källberg M, et al.** Nat Protoc. 2012 Jul 19;7(8):1511-22. PMID: 22814390 PMCID: PMC4730388 DOI: 10.1038/nprot.2012.085

4) [Enhanced fold recognition using efficient short fragment clustering](https://pubmed.ncbi.nlm.nih.gov/27882309/). **Krissinel E.** J Mol Biochem. 2012;1(2):76-85. PMID: 27882309 PMCID: PMC5117261

5) [Overview of the CCP4 suite and current developments](https://pubmed.ncbi.nlm.nih.gov/21460441/). **Winn MD et al.** Acta Crystallogr D Biol Crystallogr. 2011 Apr;67(Pt 4):235-42. PMID: 21460441 PMCID: PMC3069738 DOI: 10.1107/S0907444910045749

6) [Improved protein structure prediction using predicted interresidue orientations](https://pubmed.ncbi.nlm.nih.gov/31896580/). **Yang J, Anishchenko I, Park H, Peng Z, Ovchinnikov S, Baker D.** Proc Natl Acad Sci USA. 2020 Jan 21;117(3):1496-1503. PMID: 31896580 PMCID: PMC6983395 DOI: 10.1073/pnas.1914677117

7) [UCSF ChimeraX: Structure visualization for researchers, educators, and developers](https://www.ncbi.nlm.nih.gov/pubmed/32881101). **Pettersen EF, Goddard TD, Huang CC, Meng EC, Couch GS, Croll TI, Morris JH, Ferrin TE**. Protein Sci. 2021 Jan;30(1):70-82.  PMID: 32881101 PMCID: PMC7737788 DOI: 10.1002/pro.3943

8) [Highly accurate protein structure prediction with AlphaFold](https://pubmed.ncbi.nlm.nih.gov/34265844/). **Jumper J,** ***et al.*** Nature. 2021 Jul 15. Online ahead of print. PMID: 34265844 DOI: 10.1038/s41586-021-03819-2.

9) [Accurate prediction of protein structures and interactions using a three-track neural network](https://pubmed.ncbi.nlm.nih.gov/34282049/). **Baek M,** ***et al.*** Science. 2021 Jul 15; eabj8754. Online ahead of print. PMID: 34282049 DOI: 10.1126/science.abj8754

10) [A local superposition-free score for comparing protein structures and models using distance difference tests](https://pubmed.ncbi.nlm.nih.gov/23986568/). **Mariani V, Biasini M, Barbato A, Schwede T**. Bioinformatics. 2013 Nov 1;29(21):2722-8.  PMID: 23986568 PMCID: PMC3799472 DOI: 10.1093/bioinformatics/btt473.
</details>
