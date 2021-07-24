#!/usr/bin/bash

## On Fedora 34
sudo dnf install aria2 perl-App-cpanminus

## Installing HH-suite with AVX2 - https://github.com/soedinglab/hh-suite
HHSUITE=/opt/hhsuite
mkdir -p $HHSUITE
cd $HHSUITE
aria2c -x10 https://github.com/soedinglab/hh-suite/releases/download/v3.3.0/hhsuite-3.3.0-AVX2-Linux.tar.gz
tar xvfz hhsuite-3.3.0-AVX2-Linux.tar.gz
rm hhsuite-3.3.0-AVX2-Linux.tar.gz
echo "export PATH=$PATH:$(pwd)/bin:$(pwd)/scripts" >> ~/.bashrc

## Downloading trRosetta from GitHub:
git clone https://github.com/gjoni/trRosetta
cd trRosetta

## Setting up trRosetta installation directory:
echo "export TRROSETTA_HOME=$(pwd)" >> ~/.bashrc

## Downloading trRosetta pre-trained network:
aria2c -x10 https://files.ipd.uw.edu/pub/trRosetta/model2019_07.tar.bz2
tar -xvf model2019_07.tar.bz2

## Must also download trRosetta structure modeling scripts manually - trRosetta package (28M).
firefox https://yanglab.nankai.edu.cn/trRosetta/download/
cd ~/Downloads/
tar -xvf trRosetta.tar.bz2
mv trRosetta $TRROSETTA_HOME/trRosetta_scripts
echo "export TRROSETTA_SCRIPTS=$TRROSETTA_HOME/trRosetta_scripts" >> ~/.bashrc

## To install tensorflow with GPU in conda:
## The files can eat through GPU VRAM very quickly. 8 Gb is usually insufficient...
# conda create -n tfgpu python=3.7
# conda activate tfgpu
# pip install tensorflow-gpu==1.15
# pip install numpy==1.19.5
# conda install cudatoolkit==10.0.130
# conda install cudnn==7.6.5

## To install tensorflow with CPU in conda:
conda create -n tfcpu python=3.7
conda activate tfcpu
pip install tensorflow-cpu==1.15
pip install numpy==1.19.5

## Installing PyRosetta [Python-3.7.Release] inside conda
## Goto https://www.pyrosetta.org/downloads to download/request a license
## See https://www.pyrosetta.org/downloads#h.abjy686qantw for detailed instructions
tar -xvf `ls PyRosetta4.Release.python37*`
cd PyRosetta4.Release.python37.linux.release-289/
cd setup && python setup.py install
cd ../../

## To test PyRosetta installation
## python
## import pyrosetta; pyrosetta.init()
## quit()

## Removing PyRosetta installation files
rm -R PyRosetta4.Release.python37*



