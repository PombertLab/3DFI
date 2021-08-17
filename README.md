<p align="left"><img src="https://github.com/PombertLab/3DFI/blob/master/Images/Logo.png" alt="3DFI - Three-dimensional function inference" width="800"></p>

The 3DFI pipeline automates 3D structure prediction, structural homology searches and data visualization at the genome scale. Protein structures predicted in PDB format are searched against a local copy of the [RSCB PDB](https://www.rcsb.org/) database with GESAMT (General Efficient Structural Alignment of Macromolecular Targets) from the [CCP4](https://www.ccp4.ac.uk/) package. Known PDB structures can also be searched against sets of predicted structures to identify potential structural homologs in predicted datasets.

## Table of contents
* [Introduction](#introduction)
* [Requirements](#requirements)
* [Installation](#installation)
* [Howto](#howto)
  * [3D structure prediction](#3D-structure-prediction)
    * [RaptorX](#Raptorx---template-based-protein-structure-modeling)
    * [trRosetta](#trRosetta---deep-learning-based-protein-structure-modeling)
	* [trRosetta2](#trRosetta2---deep-learning-based-protein-structure-modeling)
    * [AlphaFold2](#AlphaFold2---deep-learning-based-protein-structure-modeling)
	* [RoseTTAFOLD](#RoseTTAFOLD---deep-learning-based-protein-structure-modeling)
  * [Structural homology searches](#Structural-homology-searches)
    * [Downloading PDB files from RCSB](#downloading-PDB-files-from-RCSB)
    * [Creating a list of PDB titles](#creating-a-list-of-PDB-titles)
    * [Creating or updating a GESAMT database](#creating-or-updating-a-GESAMT-database)
    * [Structural homology searches with GESAMT](#structural-homology-searches-with-GESAMT)
    * [Parsing the output of GESAMT searches](#Parsing-the-output-of-GESAMT-searches)
  * [Structural visualization](#Structural-visualization)
    * [About visualization](#About-visualization)
    * [Inspecting alignments with ChimeraX](#Inspecting-alignments-with-ChimeraX)
    * [Coloring AlphaFold2 predictions per B-factor](#Coloring-AlphaFold2-predictions-per-B-factor)
* [Miscellaneous](#miscellaneous)
* [Funding and acknowledgments](#Funding-and-acknowledgments)
* [References](#references)

### Introduction
###### About function inferences
Inferring the function of proteins using computational approaches usually involves performing some sort of homology search based on sequences or structures. In sequence-based searches, nucleotide or amino acid sequences are queried against known proteins or motifs using tools such as [BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi), [DIAMOND](https://github.com/bbuchfink/diamond), [CDD](https://www.ncbi.nlm.nih.gov/Structure/cdd/wrpsb.cgi), or [Pfam](https://pfam.xfam.org/), but those searches may fail if the proteins investigated are highly divergent. In structure-based searches, proteins are searched instead at the 3D level for structural homologs.

###### Why structural homologs?
Because structure often confers function in biology, structural homologs often share similar functions, even if the building blocks are not the same (*i.e.* a wheel made of wood or steel is still a wheel regardless of its composition). Using this approach, we might be able to infer putative functions for proteins that share little to no similarity at the sequence level with known proteins, assuming that a structural match can be found.

###### What is needed for structure-based homology searches?
To perform structure-based predictions we need 3D structures — either determined experimentally or predicted computationally — that we can query against other structures, such as those from the [RCSB PDB](https://www.rcsb.org/). We also need tools that can search for homology at the structural level. Several tools are now available to predict protein structures, many of which are implemented as web servers for ease of use. A listing can be found at [CAMEO](https://www.cameo3d.org/), a website that evaluates their accuracy and reliability. Fewer tools are available to perform searches at the 3D levels (*e.g.* SSM and GESAMT). SSM is implemented in [PDBeFold](https://www.ebi.ac.uk/msd-srv/ssm/) while GESAMT is part of the [CCP4](https://www.ccp4.ac.uk/) package.

###### Why this pipeline?
Although predicting the structure of a protein and searching for structural homologs can be done online, for example by using [SWISS-MODEL](https://swissmodel.expasy.org/) and [PDBeFold](https://www.ebi.ac.uk/msd-srv/ssm/), genomes often code for thousands of proteins and applying this approach on a genome scale would be time consuming and error prone. We implemented the 3DFI pipeline to enable the use of structure-based homology searches at a genome-wide level.

### Requirements
Requirements to perform 3D structure prediction, structural homology searches and data visualization locally with 3DFI are as follows:
1. At least one of the following protein structure prediction tools:
	- [RaptorX](http://raptorx.uchicago.edu/) (Template-based predictions)
	- [trRosetta](https://github.com/gjoni/trRosetta) (Deep-learning-based predictions) 
	- [trRosetta2](https://github.com/RosettaCommons/trRosetta2) (Deep-learning-based predictions) 
	- [AlphaFold2](https://github.com/deepmind/alphafold) (Deep-learning-based predictions)
	- [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) (Deep-learning-based predictions)
2. Their dependencies, e.g.:
	- [MODELLER](https://salilab.org/modeller/) (for RaptorX)
	- [PyRosetta](http://www.pyrosetta.org/) (for trRosetta/trRosetta2)
	- [Docker](https://www.docker.com/) (for AlphaFold2)
	- [Conda](https://docs.conda.io/en/latest/) (for RoseTTAFold)
3. GESAMT from the [CCP4](https://www.ccp4.ac.uk/) package to perform structural homology searches 
4. UCSF [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html) to align and visualize structural homologs
5. Perl modules (most of which should be bundled with [Perl 5]((https://www.perl.org/)))
	- [File::Basename](https://perldoc.perl.org/File/Basename.html)
	- [File::Find](https://perldoc.perl.org/File/Find.html)
	- [Getopt::Long](https://perldoc.perl.org/Getopt/Long.html)
	- [PerlIO::gzip](https://metacpan.org/pod/PerlIO::gzip)
	- [threads::shared](https://perldoc.perl.org/threads::shared)

Alternatively, any set of PDB files can be fed as input for structural homology searches/visualization with GESAMT/ChimeraX. For example, protein structures predicted using web-based platforms such as [SWISS-MODEL](https://swissmodel.expasy.org/), predicted locally with pipelines like [I-TASSER](https://zhanglab.ccmb.med.umich.edu/I-TASSER/download/), or downloaded from the new EMBL-EBI/Deepmind [AlphaFold Protein Structure Database](https://alphafold.ebi.ac.uk/) can be used as queries for structural homology searches.

### Installation
The 3DFI pipeline can be downloaded directly from GitHub with git clone. For ease of use, the 3DFI directories can be also be set as environment variables. The script [setup_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/setup_3DFI.pl) can be used to facilitate this process. 

```Bash
## To download 3DFI from GitHub:
git clone https://github.com/PombertLab/3DFI.git

## To set 3DFI directories as environment variables:
cd 3DFI/
export TDFI=$(pwd)
export RX_3DFI=$TDFI/Prediction/RaptorX
export TR_3DFI=$TDFI/Prediction/trRosetta
export TR2_3DFI=$TDFI/Prediction/trRosetta2
export AF_3DFI=$TDFI/Prediction/AlphaFold2
export RF_3DFI=$TDFI/Prediction/RoseTTAFold
export HS_3DFI=$TDFI/Homology_search
export VZ_3DFI=$TDFI/Visualization

## To set 3DFI directories as environment variables with setup_3DFI.pl:
setup_3DFI.pl \
  -p ~/GitHub/3DFI/ \
  -c ~/.bashrc
```

Options for [setup_3DFI.pl](https://github.com/PombertLab/3DFI/blob/master/setup_3DFI.pl) are:
```
-p (--path)	Path to 3DFI installation directory [Default: ./]
-c (--config)	Configuration file to edit
```

### Howto
#### 3D structure prediction
##### RaptorX - template-based protein structure modeling
To perform template-based 3D structure predictions locally with [RaptorX](http://raptorx.uchicago.edu/), the standalone programs should be [downloaded](http://raptorx.uchicago.edu/download/) and installed according to the authors’ instructions. Using RaptorX also requires [MODELLER](https://salilab.org/modeller/). To help with their installation, the [raptorx_installation_notes.sh](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx_installation_notes.sh) is provided, with source and installation directories to be edited according to user preferences.

To run [RaptorX](http://raptorx.uchicago.edu/) from anywhere with [raptorx.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx.pl), the environment variable RAPTORX_HOME should be set first:

```Bash
## Setting up the RaptorX installation directory as an environment variable:
export RAPTORX_HOME=/opt/RaptorX

## Creating a working directory for RaptorX:
export RESULTS=~/Results_3DFI
export RX=$RESULTS/RAPTORX_3D
mkdir -p $RESULTS $RX
```

To predict 3D structures with [RaptorX](http://raptorx.uchicago.edu/) using [raptorx.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx.pl):

```bash
## Running RaptorX on provided examples:
$RX_3DFI/raptorx.pl \
   -t 10 \
   -k 2 \
   -i $TDFI/Examples/FASTA \
   -o $RX
```

Options for [raptorx.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx.pl) are:

```
-t (--threads)	Number of threads to use [Default: 10]
-i (--input)	Folder containing fasta files
-o (--output)	Output folder
-k (--TopK)	Number of top template(s) to use per protein for model building [Default: 1]
-m (--modeller)	MODELLER binary name [Default: mod10.1] ## Use absolute or relative path if not set in \$PATH
```

NOTES:
- If segmentation faults occur on AMD ryzen CPUs with the blastpgp version provided with the RaptorX CNFsearch1.66_complete.zip package (under util/BLAST), replace it with the latest BLAST legacy version (2.2.26) from [NCBI](https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/).

- The following warning message about 6f45D can be safely ignored; it refers to a problematic file in the RaptorX datasets but does not impede folding. To silence this error message, see how to remove references to 6f45D in [raptorx_installation_notes.sh](https://github.com/PombertLab/3DFI/blob/master/Prediction/RaptorX/raptorx_installation_notes.sh).
```
.....CONTENT BAD AT TEMPLATE FILE /path/to/RaptorX_databases/TPL_BC100//6f45D.tpl -> [FEAT line 115 CA_contact 21]
template file 6f45D format bad or missing
```
- RaptorX expects a PYTHONHOME environment variable but runs fine without it. The following warning message can be safely ignored, and silenced by setting up a PYTHONHOME environment variable. Note that setting PYTHONHOME can create issues with other applications.
```renamed env vars for consistencyindependent libraries <prefix>
Could not find platform dependent libraries <exec_prefix>
Consider setting $PYTHONHOME to <prefix>[:<exec_prefix>]
```
- The import site warning message below can also be safely ignored:
```
'import site' failed; use -v for traceback
```


##### trRosetta - deep-learning-based protein structure modeling
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

Options for [fasta_oneliner.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/fasta_oneliner.pl) are:

```
-f (--fasta)    FASTA files to convert
-o (--output)   Output folder
```

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

Options for [run_hhblits.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/run_hhblits.pl) are:

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

3. To create .npz files containing inter-residue geometries with [create_npz.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/create_npz.pl), type:
```Bash
## activate conda environment tfcpu or tfgpu
conda activate tfcpu

## Creating npz files:
$TR_3DFI/create_npz.pl \
   -a $TR/HHBLITS/*.a3m \
   -o $TR/NPZ/
```

Options for [create_npz.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/create_npz.pl) are:

```
-a (--a3m)		.a3m files generated by hhblits
-o (--output)		Output folder [Default: ./]
-t (--trrosetta)	trRosetta installation directory (TRROSETTA_HOME)
-m (--model)		trRosetta model directory [Default: model2019_07]
```

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

Options for [create_pdb.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/create_pdb.pl) are:

```
-c (--cpu)		Number of cpu threads to use [Default: 10] ## i.e. runs n processes in parallel
-m (--memory)		Memory available (in Gb) to threads [Default: 16] 
-n (--npz)		Folder containing .npz files
-o (--output)		Output folder [Default: ./]
-f (--fasta)		Folder containing the oneliner fasta files
-t (--trrosetta)	trRosetta installation directory (TRROSETTA_HOME)
-p (--python)		Preferred Python interpreter [Default: python]
```

5. The .pdb files thus generated contain lines that are not standard and that can prevent applications such as [PDBeFOLD](https://www.ebi.ac.uk/msd-srv/ssm/) to run on the corresponding files. We can clean up the PDB files with [sanitize_pdb.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/sanitize_pdb.pl) as follows:

```Bash
$TR_3DFI/sanitize_pdb.pl \
   -p $TR/PDB/*.pdb \
   -o $TR/PDB_clean
```

Options for [sanitize_pdb.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta/sanitize_pdb.pl) are:

```
-p (--pdb)      .pdb files generated by trRosetta
-o (--output)   Output folder
```

##### trRosetta2 - deep-learning-based protein structure modeling
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

Options for [fasta_oneliner.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/fasta_oneliner.pl) are:

```
-f (--fasta)    FASTA files to convert
-o (--output)   Output folder
```

To run [trRosetta2](https://github.com/RosettaCommons/trRosetta2) in batch mode with [trRosetta2.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/trRosetta2.pl), type:
```Bash
$TR2_3DFI/trRosetta2.pl \
   -f $TR2/FASTA_OL/*.fasta \
   -o $TR2/TROS2_3D \
   -g
```

Options for [trRosetta2.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/trRosetta2/trRosetta2.pl) are:

```
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-g (--gpu)		Uses GPU acceleration (>= 16 Gb video RAM recommended); defaults to CPU otherwize
-t (--trrosetta2)	trRosetta2 installation directory
```

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

Options for [parse_af_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/parse_af_results.pl) are:

```
-r (--r2dir)	trRosetta2 output directory
-o (--outdir)	Parsed output directory
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
```

##### AlphaFold2 - deep-learning-based protein structure modeling
How to set up [AlphaFold2](https://github.com/deepmind/alphafold) to run as a docker image is described on its GitHub page. Notes about how to install it on Fedora 33/34 with CUDA 11.1+ (for GPUs with compute capability 8.6) are available in [af2_installation_notes.sh](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/af2_installation_notes.sh).

The [alphafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/alphafold.pl) script is a Perl wrapper that enables running AlphaFold2 in batch mode. To simplify its use, the ALPHA_HOME and ALPHA_OUT environment variables can be set in the shell.

```bash
## Setting up AlphaFold2 installation directory and output folder as environment variables:
export ALPHA_HOME=/opt/alphafold
export ALPHA_OUT=/media/Data/alphafold_results

## Creating a working directory for AlphaFold2:
export RESULTS=~/Results_3DFI
export AF=$RESULTS/ALPHAFOLD_3D
mkdir -p $RESULTS $AF
```

To run [alphafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/alphafold.pl) on multiple fasta files, type:

```bash
$AF_3DFI/alphafold.pl \
   -f $TDFI/Examples/FASTA/*.fasta \
   -o $AF/Results
```

Options for [alphafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/alphafold.pl) are:

```
-f (--fasta)		FASTA files to fold
-o (--outdir)		Output directory
-m (--max_date)		--max_template_date option (YYYY-MM-DD) from AlphaFold2 [Default: current date]
-c (--casp14)		casp14 preset (--preset=casp14)
-d (--full_dbs)		full_dbs preset (--preset=full_dbs)
-n (--no_gpu)		Turns off GPU acceleration
-ah (--alpha_home)	AlphaFold2 installation directory
-ao (--alpha_out)	AlphaFold2 output directory
```

Folding results per protein will be located in corresponding subdirectories. Results with AlphaFold will contain PDB files for unrelaxed models (*i.e.* predicted as is before relaxation), relaxed models, and ranked models from best (0) to worst (4). Each subdirectory should look like this:

```bash
ls -l $AF/Results/sequence_1/
total 4
total 47404
-rw-r--r-- 1 jpombert jpombert 1085545 Jul 23 08:27 features.pkl
drwxr-xr-x 1 jpombert jpombert     106 Jul 23 08:27 msas
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 ranked_0.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 ranked_1.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 ranked_2.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 ranked_3.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 ranked_4.pdb
-rw-r--r-- 1 jpombert jpombert     327 Jul 23 08:27 ranking_debug.json
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 relaxed_model_1.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 relaxed_model_2.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 relaxed_model_3.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 relaxed_model_4.pdb
-rw-r--r-- 1 jpombert jpombert  149210 Jul 23 08:27 relaxed_model_5.pdb
-rw-r--r-- 1 jpombert jpombert 9084306 Jul 23 08:27 result_model_1.pkl
-rw-r--r-- 1 jpombert jpombert 9084306 Jul 23 08:27 result_model_2.pkl
-rw-r--r-- 1 jpombert jpombert 9127362 Jul 23 08:27 result_model_3.pkl
-rw-r--r-- 1 jpombert jpombert 9127362 Jul 23 08:27 result_model_4.pkl
-rw-r--r-- 1 jpombert jpombert 9127362 Jul 23 08:27 result_model_5.pkl
-rw-r--r-- 1 jpombert jpombert     766 Jul 23 08:27 timings.json
-rw-r--r-- 1 jpombert jpombert   73112 Jul 23 08:27 unrelaxed_model_1.pdb
-rw-r--r-- 1 jpombert jpombert   73112 Jul 23 08:27 unrelaxed_model_2.pdb
-rw-r--r-- 1 jpombert jpombert   73112 Jul 23 08:27 unrelaxed_model_3.pdb
-rw-r--r-- 1 jpombert jpombert   73112 Jul 23 08:27 unrelaxed_model_4.pdb
-rw-r--r-- 1 jpombert jpombert   73112 Jul 23 08:27 unrelaxed_model_5.pdb
```

The script [parse_af_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/parse_af_results.pl) can be used to recurse through the subdirectories and copy the PDB model(s) with more descriptive names including the prefixes of the FASTA files to a selected location. To use [parse_af_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/parse_af_results.pl),  type:

```bash
$AF_3DFI/parse_af_results.pl \
  -a $AF/Results \
  -o $AF/Parsed_PDBs \
  -p k \
  -t 5
```

Options for [parse_af_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/AlphaFold2/parse_af_results.pl) are:
```
-a (--afdir)	AlphaFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	ranked (k), relaxed (r), unrelaxed (u), all (a) [Default: k]
-t (--top)	Top X number of pdb files to keep, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
```

##### RoseTTAFold - deep-learning-based protein structure modeling
How to set up [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) to run using conda is described on its GitHub page. Notes about how to install it on Fedora 33/34 are available in [rfold_installation_notes.sh](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/rfold_installation_notes.sh).

The [rosettafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/rosettafold.pl) script is a Perl wrapper that enables running the [RoseTTAFold](https://github.com/RosettaCommons/RoseTTAFold) run_e2e_ver.sh / run_pyrosetta_ver.sh scripts in batch mode. To simplify its use, the ROSETTAFOLD_HOME environment variable can be set in the shell.

```bash
##  Setting up RoseTTAFold installation directory as an environment variable:
export ROSETTAFOLD_HOME=/opt/RoseTTAFold

## Creating a working directory for RoseTTAFold:
export RESULTS=~/Results_3DFI
export RF=$RESULTS/ROSETTAFOLD_3D
mkdir -p $RESULTS $RF
```

To run [rosettafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/rosettafold.pl) on multiple fasta files, type:

```bash
$RF_3DFI/rosettafold.pl \
   -f $TDFI/Examples/FASTA/*.fasta \
   -o $RF/e2e/
```

Options for [rosettafold.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/rosettafold.pl) are:

```
-f (--fasta)	FASTA files to fold
-o (--outdir)	Output directory
-t (--type)	Folding type: pyrosetta (py) or end-to-end (e2e)  [Default: e2e]
-r (--rosetta)	RoseTTAFold installation directory
```

Note that the e2e folding option is constrained by video RAM and requires a CUDA-enabled GPU with more than 8 Gb of RAM to tackle large proteins (a video card with at least 24 Gb of RAM is recommended). If out of memory, the 'RuntimeError: CUDA out of memory' will appear in the log/network.stderr file and the .pdb file will not be generated. The pyrosetta folding option is slower (CPU-bound) but not constrained by video RAM.

Folding results per protein will be located in corresponding subdirectories. Results with the e2e option should look like below, with the model generated named t000_.e2e.pdb:

```bash
ls -l  $RF/e2e/sequence_1/
total 4248
drwxrwxr-x 1 jpombert jpombert     508 Jul 22 14:45 hhblits
drwxrwxr-x 1 jpombert jpombert     232 Jul 22 14:45 log
-rw-rw-r-- 1 jpombert jpombert  914410 Jul 22 14:45 t000_.atab
-rw-rw-r-- 1 jpombert jpombert   23517 Jul 22 14:46 t000_.e2e_init.pdb
-rw-rw-r-- 1 jpombert jpombert 2873473 Jul 22 14:46 t000_.e2e.npz
-rw-rw-r-- 1 jpombert jpombert   31356 Jul 22 14:46 t000_.e2e.pdb
-rw-rw-r-- 1 jpombert jpombert  481742 Jul 22 14:45 t000_.hhr
-rw-rw-r-- 1 jpombert jpombert    3941 Jul 22 14:45 t000_.msa0.a3m
-rw-rw-r-- 1 jpombert jpombert    4195 Jul 22 14:45 t000_.msa0.ss2.a3m
-rw-rw-r-- 1 jpombert jpombert     254 Jul 22 14:45 t000_.ss2
``` 

Results with the pyrosetta option should look like below, with the models generated (5 in total) located in the model/ subfolder:

```bash
ls -l $RF/py/sequence_1/
total 4284
drwxrwxr-x 1 jpombert jpombert     508 Jul 22 15:28 hhblits
drwxrwxr-x 1 jpombert jpombert     388 Jul 22 15:45 log
drwxrwxr-x 1 jpombert jpombert     310 Jul 22 15:45 model
-rw-rw-r-- 1 jpombert jpombert    4125 Jul 22 15:29 parallel.fold.list
drwxrwxr-x 1 jpombert jpombert    1020 Jul 22 15:45 pdb-3track
-rw-rw-r-- 1 jpombert jpombert 2959088 Jul 22 15:29 t000_.3track.npz
-rw-rw-r-- 1 jpombert jpombert  914410 Jul 22 15:29 t000_.atab
-rw-rw-r-- 1 jpombert jpombert  481760 Jul 22 15:29 t000_.hhr
-rw-rw-r-- 1 jpombert jpombert    3941 Jul 22 15:28 t000_.msa0.a3m
-rw-rw-r-- 1 jpombert jpombert    4195 Jul 22 15:28 t000_.msa0.ss2.a3m
-rw-rw-r-- 1 jpombert jpombert     254 Jul 22 15:28 t000_.ss2
```

The script [parse_rf_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/parse_rf_results.pl) can be used to recurse through the subdirectories and copy the PDB model(s) with more descriptive names including the prefixes of the FASTA files to a selected location. To use [parse_rf_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/parse_rf_results.pl),  type:

```bash
$RF_3DFI/parse_rf_results.pl \
  -r $RF/e2e \
  -o $RF/e2e_parsed \
  -p e2e
```

Options for [parse_rf_results.pl](https://github.com/PombertLab/3DFI/blob/master/Prediction/RoseTTAFold/parse_rf_results.pl) are:
```
-r (--rfdir)	RoseTTAFold output directory
-o (--outdir)	Parsed output directory
-p (--pdbtype)	PDB type: pyrosetta (py) or end-to-end (e2e) [Default: e2e]
-t (--top)	Top X number of pdb files to keep for pyrosetta PDBs, from best to worst (max 5) [Default: 1]
-v (--verbose)	Adds verbosity
```

#### Structural homology searches
##### Downloading PDB files from RCSB
PDB files from the [Protein Data Bank](https://www.rcsb.org/) can be downloaded directly from its website. Detailed instructions are provided [here](https://www.wwpdb.org/ftp/pdb-ftp-sites). Because of the large size of this dataset, downloading it using [rsync](https://rsync.samba.org/) is recommended. This can be done with [update_PDB.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/update_PDB.pl) as follows:

```bash
## Setting up RCSB PDB database location:
export RCSB_PDB=/media/FatCat/databases/RCSB_PDB/

## Downloading the RCSB PDB database:
$HS_3DFI/update_PDB.pl \
  -o $RCSB_PDB \
  -n 15 \
  -v
```

Options for [update_PDB.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/update_PDB.pl) are:
```
-o (--outdir)	PDB output directory [Default: PDB]
-n (--nice)	Defines niceness (adjusts scheduling priority)
-v (--verbose)	Adds verbosity
```

##### Creating a list of PDB titles
To create a tab-delimited list of PDB entries and their titles and chains from the downloaded PDB gzipped files (pdb*.ent.gz), we can use [PDB_headers.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/PDB_headers.pl) (requires [PerlIO::gzip](https://metacpan.org/pod/PerlIO::gzip)):

```Bash
## Setting up 3DFI results location:
export RESULTS=~/Results_3DFI

## Running a list of titles and chains from PDB files
$HS_3DFI/PDB_headers.pl \
   -p $RCSB_PDB \
   -o $RESULTS/PDB_titles.tsv
```

Options for [PDB_headers.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/PDB_headers.pl) are:

```
-p (--pdb)	Directory containing PDB files downloaded from RCSB PDB/PDBe (gzipped)
-o (--output)	Output file in tsv format
-v (--verbose)	Prints progess every X file [Default: 1000]
```

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
export GESAMT_ARCHIVE=/media/FatCat/databases/GESAMT_ARCHIVE/

## To create a GESAMT archive:
$HS_3DFI/run_GESAMT.pl \
   -cpu 10 \
   -make \
   -arch $GESAMT_ARCHIVE \
   -pdb $RCSB_PDB

## To update a GESAMT archive:
$HS_3DFI/run_GESAMT.pl \
   -cpu 10 \
   -update \
   -arch $GESAMT_ARCHIVE \
   -pdb $RCSB_PDB
```
Options to create/update a GESAMT archive with [run_GESAMT.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/run_GESAMT.pl) are:
```
-c (--cpu)	CPU threads [Default: 10]
-a (--arch)	GESAMT archive location [Default: ./]
-m (--make)	Create a GESAMT archive
-u (--update)	Update existing archive
-p (--pdb)	Folder containing RCSB PDB files to archive
```

##### Structural homology searches with GESAMT
Structural homology searches with GESAMT can also be performed with [run_GESAMT.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/run_GESAMT.pl):

```Bash
## Creating a working directory for GESAMT:
export RESULTS=~/Results_3DFI
export GSMT=$RESULTS/GESAMT_RESULTS
mkdir -p $RESULTS $GSMT

## Performing structural homology searches with GESAMT:
$HS_3DFI/run_GESAMT.pl \
   -cpu 10 \
   -query \
   -arch $GESAMT_ARCHIVE \
   -input $TDFI/Examples/PDB/*.pdb \
   -o $GSMT \
   -mode normal
```
Options to query a GESAMT archive with [run_GESAMT.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/run_GESAMT.pl) are:
```
-c (--cpu)	CPU threads [Default: 10]
-a (--arch)	GESAMT archive location [Default: ./]
-q (--query)	Query a GESAMT archive
-i (--input)	PDF files to query
-o (--outdir)	Output directory [Default: ./]
-d (--mode)	Query mode: normal of high [Default: normal]
```

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
$HS_3DFI/descriptive_GESAMT_matches.pl \
   -r $RESULTS/PDB_titles.tsv \
   -m $GSMT/*.gesamt \
   -q 0.3 \
   -b 5 \
   -o $RESULTS/GESAMT.matches
```

Options for [descriptive_GESAMT_matches.pl](https://github.com/PombertLab/3DFI/blob/master/Homology_search/descriptive_GESAMT_matches.pl) are:

```
-r (--rcsb)	Tab-delimited list of RCSB structures and their titles ## see PDB_headers.pl 
-p (--pfam)	Tab-delimited list of PFAM structures and their titles (http://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.clans.tsv.gz)
-m (--matches)	Results from GESAMT searches ## see run_GESAMT.pl
-q (--qscore)	Q-score cut-off [Default: 0.3]
-b (--best)	Keep the best match(es) only (top X hits)
-o (--output)	Output name [Default: Gesamt.matches]
```

The concatenated list generated should look like:
```
### sequence_1-k0; Query mode = normal
sequence_1-k0	1	3KDF	D	0.6587	1.6953	0.1545	110	119	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
sequence_1-k0	2	1QUQ	C	0.6466	1.7595	0.1545	110	119	pdb1quq.ent.gz	PROTEIN (REPLICATION PROTEIN A 32 KD SUBUNIT)
sequence_1-k0	3	2PQA	A	0.6421	1.7176	0.1504	113	128	pdb2pqa.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
sequence_1-k0	4	3KDF	B	0.6415	1.8156	0.1545	110	118	pdb3kdf.ent.gz	REPLICATION PROTEIN A 32 KDA SUBUNIT
sequence_1-k0	5	4GNX	B	0.6381	1.7193	0.1182	110	122	pdb4gnx.ent.gz	PUTATIVE UNCHARACTERIZED PROTEIN
### sequence_2-k0; Query mode = normal
sequence_2-k0	1	3K0X	A	0.6349	1.5848	0.1163	86	99	pdb3k0x.ent.gz	PROTEIN TEN1
sequence_2-k0	2	3KF6	B	0.6186	1.4624	0.1163	86	105	pdb3kf6.ent.gz	PROTEIN TEN1
sequence_2-k0	3	5DOI	F	0.6057	1.8040	0.1310	84	93	pdb5doi.ent.gz	TELOMERASE ASSOCIATED PROTEIN P45
sequence_2-k0	4	5DOI	H	0.5974	1.8506	0.1310	84	93	pdb5doi.ent.gz	TELOMERASE ASSOCIATED PROTEIN P45
sequence_2-k0	5	5DOI	G	0.5958	1.8593	0.1310	84	93	pdb5doi.ent.gz	TELOMERASE ASSOCIATED PROTEIN P45
### sequence_3-k0; Query mode = normal
sequence_3-k0	1	5V7K	A	0.5610	1.9652	0.1262	214	255	pdb5v7k.ent.gz	PROLIFERATING CELL NUCLEAR ANTIGEN
sequence_3-k0	2	5T9D	C	0.5607	2.0399	0.1268	213	247	pdb5t9d.ent.gz	PROLIFERATING CELL NUCLEAR ANTIGEN
sequence_3-k0	3	6CX4	A	0.5590	1.9153	0.1226	212	255	pdb6cx4.ent.gz	PROLIFERATING CELL NUCLEAR ANTIGEN
sequence_3-k0	4	1PLR	A	0.5551	1.9919	0.1302	215	258	pdb1plr.ent.gz	PROLIFERATING CELL NUCLEAR ANTIGEN (PCNA)
sequence_3-k0	5	3IFV	C	0.5527	2.2070	0.1075	214	240	pdb3ifv.ent.gz	PCNA
```

#### Structural visualization
##### About visualization
Visually inspecting the predicted 3D structure of a protein is an important step in determing the validity of any identified structural homolog. Though a .pdb file may be obtained from a protein structure prediction tool, the quality of the fold may be low. Alternatively, though GESAMT may return a structural homolog with a reasonable Q-score, the quality of the alignment may be low. A low fold/alignment-quality can result in both false-positives (finding a structural homolog when one doesn't exist) and false-negatives (not finding a structural homolog when one exists). Visually inspecting protein structures and structural homolog alignments is an easy way to prevent these outcomes. This can be done with the excellent [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/) molecular visualization program.

Examples:
- A [good result](https://github.com/PombertLab/3DFI/blob/master/Images/Good_Match.png), in which both the folding and the alignment are good.
- A [false-negative](https://github.com/PombertLab/3DFI/blob/master/Images/Bad_Predicted_Fold.png), where the quality of the protein folding is low, resulting in a failure to find a structural homolog.
- A [false-positive](https://github.com/PombertLab/3DFI/blob/master/Images/Bad_Match.png), where the quality of the fold is high, but the alignment-quality is low and a pseudo-structural homolog is found.

##### Inspecting alignments with ChimeraX
To prepare visualizations for inspection, we can use [prepare_visualizations.pl](https://github.com/PombertLab/3DFI/blob/master/Visualization/prepare_visualizations.pl) to automatically align predicted proteins with their GESAMT-determined structural homologs. These alignments are performed with [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/) via its API.

```bash
## Creating shortcut to results directory
export RESULTS=~/Results_3DFI
export RCSB_PDB=/media/FatCat/databases/RCSB_PDB/

## Preparing data for visualization:
$VZ_3DFI/prepare_visualizations.pl \
    -g $TDFI/Examples/GESAMT.matches \
    -p $TDFI/Examples/PDB/ \
    -r $RCSB_PDB \
    -o $RESULTS/Visualization
```

Options for [prepare_visualizations.pl](https://github.com/PombertLab/3DFI/blob/master/Visualization/prepare_visualizations.pl) are:
```
-g (--gesamt)	GESAMT descriptive matches ## generated by descriptive_matches.pl
-p (--pred)	Absolute path to predicted .pdb files
-r (--rcsb)	Absolute path to RCSB .ent.gz files
-k (--keep)	Keep unzipped RCSB .ent files
-o (--outdir)	Output directory for ChimeraX sessions [Default: ./3D_Visualizations]
```

To inspect the 3D structures, we can run [inspect_3D_structures.pl](https://github.com/PombertLab/3DFI/blob/master/Visualization/inspect_3D_structures.pl):
```bash
$VZ_3DFI/inspect_3D_structures.pl \
    -v $RESULTS/Visualization
```

The output should result in something similar to the following:
```
	Available 3D visualizations for sequence_1-k0:

		1. sequence_1-k0.pdb
		2. sequence_1_1quq.cxs
		3. sequence_1_2pqa.cxs
		4. sequence_1_3kdf.cxs
		5. sequence_1_4gnx.cxs


	Options:

		[1-5] open corresponding file
		[a] advance to next locus tag
		[p] return to previous locus tag
		[n] to create a note for locus tag
		[x] to exit 3D inspection

		Selection:

```

In this example, selecting [1] will open the visualization of the predicted 3D structure with [ChimeraX](https://www.rbvi.ucsf.edu/chimerax/download.html):

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/Just_PDB.png">

The structure can then be interacted with using ChimeraX [commands](https://www.rbvi.ucsf.edu/chimerax/docs/user/index.html). For example, the structure can be colored with a rainbow scheme to better distinguish between structural domains:

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/Just_PDB_rainbow.png">

Alternatively, selecting [2-6] will open the visualization of the alignment of the predicted 3D structure with its selected structural homolog:

<img src="https://github.com/PombertLab/3DFI/blob/master/Images/With_Alignment.png">

##### Coloring AlphaFold2 predictions per B-factor
AlphaFold2 adds pLDDT (predicted lDDT-Cα) per-residue confidence scores to the B-factor columns of the PDB files it generates (as of 2021-08-13). To color these stuctures similarly to the scheme used in the DeepMind/EBI [AlphaFold Protein Structure Database](https://alphafold.ebi.ac.uk/), we can use the following ChimeraX command:
```
color byattribute bfactor palette orangered:yellow:cyan:blue range 50,100
```
<img src="https://github.com/PombertLab/3DFI/blob/master/Images/bfactor.png">

Note that to save an image with a transparent background in Chimerax (see [manual](https://www.cgl.ucsf.edu/chimerax/docs/user/commands/save.html)), we can use:
```
save ~/bfactor.png transparentBackground True
```

#### Miscellaneous 
###### Splitting multifasta files
Single FASTA files for protein structure prediction can be created with [split_Fasta.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/split_Fasta.pl):
```
split_Fasta.pl \
   -f file.fasta \
   -o output_folder \
   -e fasta
```

If desired, single sequences can further be subdivided into smaller segments using sliding windows. This can be useful for very large proteins, which can be difficult to fold computationally. Options for [split_Fasta.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/split_Fasta.pl) are:
```
-f (--fasta)	FASTA input file (supports gzipped files)
-o (--output)	Output directory [Default: Split_Fasta]
-e (--ext)	Desired file extension [Default: fasta]
-w (--window)	Split individual fasta sequences into fragments using sliding windows [Default: off]
-s (--size)	Size of the the sliding window [Default: 250 (aa)]
-l (--overlap)	Sliding window overlap [Default: 100 (aa)]
```

###### Splitting PDB files
RCSB PDB files can be split per chain with [split_PDB.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/split_PDB.pl):
```
split_PDB.pl \
   -p files.pdb \
   -o output_folder \
   -e pdb
```

Options for [split_PDB.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/split_PDB.pl) are:
```
-p (--pdb)	PDB input file (supports gzipped files)
-o (--output)	Output directory. If blank, will create one folder per PDB file based on file prefix
-e (--ext)	Desired file extension [Default: pdb]
```

###### Renaming files
Files can be renamed using regular expressions with [rename_files.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/rename_files.pl):
```
rename_files.pl \
   -o 'i{0,1}-t26_1-p1' \
   -n '' \
   -f *.fasta
```

Options for [rename_files.pl](https://github.com/PombertLab/3DFI/blob/master/Misc_tools/rename_files.pl) are:
```
-o (--old)	Old pattern/regular expression to replace with new pattern
-n (--new)	New pattern to replace with; defaults to blank [Default: '']
-f (--files)	Files to rename
```

## Funding and acknowledgments
This work was supported in part by the National Institute of Allergy and Infectious Diseases of the National Institutes of Health (award number R15AI128627) to Jean-Francois Pombert. The content is solely the responsibility of the authors and does not necessarily represent the official views of the National Institutes of Health.

##### REFERENCES
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

