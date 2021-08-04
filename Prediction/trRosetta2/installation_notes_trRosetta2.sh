#!/usr/bin/bash

##### trRosetta2 installation notes
## Will require GNU-parallel and cmake (to install latest HHBlits)
## Somehow parallel was not detected after reactivating the conda environment
sudo dnf install parallel
sudo dnf install cmake

## Tested on Fedora 34 + NVIDIA GTX 1070 [8Gb RAM; Cuda 11.3]
git clone https://github.com/RosettaCommons/trRosetta2
cd trRosetta2
export TRROSETTA2_HOME=$(pwd)
./install_dependencies.sh

## Downloading weights
aria2c -x10 https://files.ipd.uw.edu/pub/trRosetta2/weights.tar.bz2
tar -xvjf weights.tar.bz2
# NOTE - Tried setting up this folder as a symlink but it creates an error in msa-net.stderr preventing completion of the pipeline:
# OSError: [Errno 40] Too many levels of symbolic links: '/media/Data_3/opt/trRosetta2/weights/trrosetta_msa/cont/params.json'

##### Setting databases directory
DBDIR=/media/Data_3/databases/trRosetta2/
mkdir -p $DBDIR && cd $DBDIR

# Downloading pdb100_2020Mar11.tar.gz
aria2c -x10 https://files.ipd.uw.edu/pub/trRosetta2/pdb100_2020Mar11.tar.gz
tar -xzvf pdb100_2020Mar11.tar.gz
ln -s $DBDIR/pdb100_2020Mar11/ $TRROSETTA2_HOME/

# Downloading UniRef30_2020_06 (same as RoseTTAFold)
aria2c -x10 http://wwwuser.gwdg.de/~compbiol/uniclust/2020_06/UniRef30_2020_06_hhsuite.tar.gz
mkdir -p UniRef30_2020_06
tar -zxvf UniRef30_2020_06_hhsuite.tar.gz -C ./UniRef30_2020_06
ln -s $DBDIR/UniRef30_2020_06 $TRROSETTA2_HOME/


##### Conda environments

##### Running on GPU

## Conda + GPU (Python 3.6.13); uses tensorflow-gpu=1.14, will it work with newer GPUs?
cd $TRROSETTA2_HOME
conda env create -f trRosetta2-gpu.yml
conda activate tros2-gpu
# Renamed Conda environments from casp14-baker to tros2-gpu/tros2-cpu in casp14-baker-linux-(gpu|cpu).yml
# to prevent clashes between gpu and cpu conda names (both were named casp14-baker)

## Installing Pyrosetta for Python 3.6 inside the Conda env - https://www.pyrosetta.org/downloads#h.abjy686qantw
PYROSETTA=~/Downloads/PyRosetta4.Release.python36.linux.release-291.tar.bz2
tar -xjvf $PYROSETTA -C ~/Downloads/
cd ~/Downloads/PyRosetta4.Release.python36.linux.release-291
cd setup && python setup.py install

## Running trRosetta2 on the GPU with run_pipeline.sh got me the following error at the trRefined step:
## Fail to find the dnn implementation 
## Fixed it by adding the following lines to $TRROSETTA2_HOME/trRefine/run_trRefine_DAN.py
import tensorflow as tf
config = tf.compat.v1.ConfigProto()
config.gpu_options.allow_growth = True
tf.compat.v1.Session(config=config)

## This fix creates a chokepoint at trRefine:
# FutureWarning: Passing (type, 1) or '1type'
#
# This is an issue with numpy 1.19 and tensorflow 1.14; works with numpy < 1.17
# Downgrading to numpy 1.16.4 fixes the issue
# Modified the .yml files accordingly in modified_trRosetta2_files/
#
# if not using the modified .yml files:
# pip uninstall numpy
# pip install numpy==1.16.4 

# Running the T1078.fa example from trRosetta2 is too much for 8Gb of VRAM on the GTX 1070, i.e.:
# failed to allocate 7.14G (7662226432 bytes) from device: CUDA_ERROR_OUT_OF_MEMORY: out of memory
#
# Trying it with sequence_1.fasta from 3DFI/Examples, which works with RoseTTAFold within 8 Gb of VRAM
# Must convert the sequence to a one-liner, e.g. with fasta_oneliner.pl
#
# With sequence_1.fasta, I got a segmentation fault with hhblits (hhblits works fine with alphafold and RoseTTAFold):
# Segmentation fault      (core dumped) $HH -i $WDIR/t000_.msa0.ss2.a3m
# This appears to be a common issue with trRosetta2 - https://github.com/RosettaCommons/trRosetta2/issues/7
#
# Fix:
# step 1) replace with the latest HHBLITS in the conda environment
# step 2) add -premerge 0 to line 48 from run_pipeline.sh
#
# Step 1) replace with latest HHBLITS in the conda environment:
which hhblits ## returns ~/.conda/envs/tros2-gpu/bin
git clone https://github.com/soedinglab/hh-suite.git
mkdir -p hh-suite/build && cd hh-suite/build
cmake -DCMAKE_INSTALL_PREFIX=~/.conda/envs/tros2-gpu/ ..
make -j 4 && make install
#
# Step 2) add -premerge 0 to line 48 from run_pipeline.sh; see modified_trRosetta2_files/
$HH -i $WDIR/t000_.msa0.ss2.a3m -o $WDIR/t000_.hhr -premerge 0 -v 0 > $WDIR/log/hhsearch.stdout 2> $WDIR/log/hhsearch.stderr

## With the fixes above, trRosetta runs fine on sequence_1.fasta with an NVIDIA GTX 1070

##### Running on CPU

## Conda + CPU (Python 3.6.13)
cd $TRROSETTA2_HOME
conda env create -f trRosetta2-cpu.yml
conda activate tros2-cpu
# Renamed Conda environments from casp14-baker to tros2-gpu/tros2-cpu in casp14-baker-linux-(gpu|cpu).yml
# to prevent clashes between gpu and cpu conda names (both were named casp14-baker)

## Installing Pyrosetta for Python 3.6 inside the Conda env - https://www.pyrosetta.org/downloads#h.abjy686qantw
PYROSETTA=~/Downloads/PyRosetta4.Release.python36.linux.release-291.tar.bz2
tar -xjvf $PYROSETTA -C ~/Downloads/
cd ~/Downloads/PyRosetta4.Release.python36.linux.release-291
cd setup && python setup.py install

## Replace HHBlits version:
which hhblits ## returns ~/.conda/envs/tros2-cpu/bin
git clone https://github.com/soedinglab/hh-suite.git
mkdir -p hh-suite/build && cd hh-suite/build
cmake -DCMAKE_INSTALL_PREFIX=~/.conda/envs/tros2-cpu/ ..
make -j 4 && make install

# if not using the modified .yml files:
# pip uninstall numpy
# pip install numpy==1.16.4 


# run_pipeline.sh has issues when run with CPU only - https://github.com/RosettaCommons/trRosetta2/issues/3
#
# Created a modified script (run_pipeline_cpu.sh) based on suggested fix by fbaltoumas on July 13, 2021 3:32AM CDT:
# https://github.com/RosettaCommons/trRosetta2/issues/3#issuecomment-878889752
# 
# Also changed CPU default to 10 in run_pipeline_cpu.sh
#
# To use with trRosetta2.pl, copy run_pipeline_cpu.sh to $TRROSETTA2_HOME 


