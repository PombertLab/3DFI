#!/usr/bin/bash

## On Fedora 34
##### Installing aria2 and conda #####
sudo dnf install aria2 conda

##### Installing RoseTTAFold - https://github.com/RosettaCommons/RoseTTAFold #####
## Setting up installation and databases directory
export INST_ROOT=/media/Data_1/opt/
export RFOLD_DB=/media/FatCat/databases/RoseTTAFold_db

mkdir -p $INST_ROOT $RFOLD_DB
cd $INST_ROOT;
git clone https://github.com/RosettaCommons/RoseTTAFold.git
cd RoseTTAFold
export ROSETTAFOLD_HOME=$(pwd)

## Creating CUDA 11 conda environments RoseTTAFold and folding and installing dependencies
conda env create -f RoseTTAFold-linux.yml
conda env create -f folding-linux.yml
cd $ROSETTAFOLD_HOME
./install_dependencies.sh

## Install PyRosetta (python 3.7) inside the folding conda environment (folding uses python 3.7)
# PyRosetta license - https://els2.comotion.uw.edu/product/pyrosetta
# PyRosetta download [1.5G] - https://www.pyrosetta.org/downloads
# PyRosetta installation - https://www.pyrosetta.org/downloads#h.abjy686qantw
conda activate folding
PYROSETTA=~/Downloads/PyRosetta4.Release.python37.linux.release-290.tar.bz2
tar -xjvf $PYROSETTA -C ~/Downloads/
cd ~/Downloads/PyRosetta4.Release.python37.linux.release-290
cd setup && python setup.py install

## To test PyRosetta installation:
# python
# import pyrosetta; pyrosetta.init()
# quit()

conda deactivate

##### Downloading databases  (see https://github.com/RosettaCommons/RoseTTAFold) #####
## Some files are huge, better to download with aria2 and -x set between 8 to 16
cd $RFOLD_DB

## Network weights - https://files.ipd.uw.edu/pub/RoseTTAFold/Rosetta-DL_LICENSE.txt
aria2c -x10 https://files.ipd.uw.edu/pub/RoseTTAFold/weights.tar.gz
tar -xzvf weights.tar.gz

## BFD (same as AlphaFold2; can be skipped if downloaded already); 272G
aria2c -x10 https://bfd.mmseqs.com/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz
mkdir -p bfd
tar xfz bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz -C ./bfd

## UniRef30 (same as trRosetta; can be skipped if downloaded already); 46G
aria2c -x10 http://wwwuser.gwdg.de/~compbiol/uniclust/2020_06/UniRef30_2020_06_hhsuite.tar.gz
mkdir -p UniRef30_2020_06
tar -xzvf UniRef30_2020_06_hhsuite.tar.gz -C ./UniRef30_2020_06

## Structure templates; > 100G 
aria2 -x10 https://files.ipd.uw.edu/pub/RoseTTAFold/pdb100_2021Mar03.tar.gz
tar -xzvf pdb100_2021Mar03.tar.gz

## Creating symlinks to RoseTTAFold databases
cd $ROSETTAFOLD_HOME
ln -s $RFOLD_DB/weights ./
ln -s $RFOLD_DB/bfd ./
ln -s $RFOLD_DB/UniRef30_2020_06 ./
ln -s $RFOLD_DB/pdb100_2021Mar03 ./

