#!/bin/bash

set -e ## exit if a command exits with a non-zero status.

# >>> conda initialize >>>
__conda_setup="$('conda' 'shell.bash' 'hook' 2> /dev/null)"
eval "$__conda_setup"
unset __conda_setup
# <<< conda initialize <<<

## Download - https://www.pyrosetta.org/downloads#h.xe4c0yjfkl19
## License - https://els2.comotion.uw.edu/product/pyrosetta
PYROSETTA="$1" # Pyrosetta [Python-3.7.Release]
TMPDIR=`realpath -s $2`  # tmp_dir
CWDDIR=`pwd`

## Activating the folding environment for RoseTTAFold
conda activate folding

mkdir -p $TMPDIR
tar -xjvf $PYROSETTA -C $TMPDIR
cd $TMPDIR/PyRosetta4.Release.python37*
cd setup && python setup.py install
cd $CWDDIR
rm -R $TMPDIR

conda deactivate