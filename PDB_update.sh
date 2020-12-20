#!/usr/bin/bash

PDB_DIR=/media/Data_2/PDB/ ## Replace with desired destination

## Downloads PDB automatically from RCSB; US mirror of PDBe
rsync -rlpt -v -z --delete --port=33444 \
rsync.rcsb.org::ftp_data/structures/divided/pdb/ $PDB_DIR
