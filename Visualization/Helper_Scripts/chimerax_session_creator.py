#!/usr/bin/python
from chimerax.core.commands import run
from sys import argv
import argparse
import re
import os

name = 'chimerax_session_creator.py'
version = '0.3'
updated = '2022-02-23'

usage = f'''
NAME		{name}
VERSION		{version}
UPDATED		{updated}

SYNOPSIS	This script is used to align a reference .pdb to a predicted .pdb,
		changes the predicted .pdb color, hides all atoms, shows only matched
		chains, and saves the result as a ChimeraX session, .cxs file. This version
		is tested and functional as of ChimeraX 1.3.1.

COMMAND		{name} \\
			-p ...preference \\
			-r ...reference

OPTIONS

-p (--pred)		Predicted .pdb file
-r (--rcsb)		RCSB .pdb file
-m (--match)	RCSB match name
-c (--chain)	RCSB matched chain
-o (--outdir)	Output directory for .cxs files [Default: ./3D_Visualizations]
'''

if len(argv) < 2:
	print(f"\n\n{usage}\n\n")
	exit()

parser = argparse.ArgumentParser(usage=usage)
parser.add_argument('-p','--pred',type=str,required=True)
parser.add_argument('-r','--rcsb',type=str)
parser.add_argument('-m','--match',type=str,default="NoFileName")
parser.add_argument('-c','--chain',type=str)
parser.add_argument('-o','--outdir',type=str,default="./3D_Visualizations")
parser.add_argument('--nogui')

args = parser.parse_args()
pred = args.pred
rcsb_match = args.match
rcsb = args.rcsb
rcsb_chain = args.chain
if(args.outdir):
	outdir = args.outdir

locus_tag = os.path.splitext(os.path.basename(pred))[0]

## Load pdb files
model_pred = run(session,f"open {pred}")[0]
model_pred_name = (model_pred.id_string)

model_rcsb = run(session,f"open {rcsb}")[0]
model_rcsb_name = (model_rcsb.id_string)


## Prepare file for display by hiding everything
run(session,"hide atoms")
run(session,"hide ribbons")

match = run(session,f"match #{model_pred_name} to #{model_rcsb_name}/{rcsb_chain}")

## Color reference structure a diferrent color
run(session,f"color #{model_rcsb_name}/{rcsb_chain} #00FFFF ribbons")

## Show only matching chains
run(session,f"show #{model_pred_name} ribbons")
run(session,f"show #{model_rcsb_name}/{rcsb_chain} ribbons")

## Orient the chain to view
run(session,"view")

## Save match as a new file
run(session,f"save {outdir}/{locus_tag}_{rcsb_match}_{rcsb_chain}.cxs format session")

quit()