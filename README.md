###### 3DFI - Three dimensional function inference
The 3DFI pipeline predicts the 3D structure of proteins and searches for structural homology in the 3D space

### SYNOPSIS
The 3DFI pipeline predicts the 3D structure of proteins and searches for structural homology in the 3D space.
Stuctures predicted are searched against a local copy the RSCB PDB database with GESAMT (General Efficient
Structural Alignment of Macromolecular Targets) from the CCP4 package.

### REQUIREMENTS
1. RaptorX - http://raptorx.uchicago.edu/
2. MODELLER - https://salilab.org/modeller/
3. GESAMT -  https://www.ccp4.ac.uk/
4. Perl modules - File::Basename, File::Find, Getopt::Long, PerlIO::gzip

### REFERENCES
1) RCSB Protein Data Bank: Sustaining a living digital data resource that enables breakthroughs in scientific research and biomedical education
Burley SK, et al. Protein Sci. 2018 Jan;27(1):316-330. PMID: 29067736 PMCID: PMC5734314 DOI: 10.1002/pro.3331

2) RaptorX: exploiting structure information for protein alignment by statistical inference
Peng J, Xu J. Proteins. 2011;79 Suppl 10:161-71. PMID: 21987485 PMCID: PMC3226909 DOI: 10.1002/prot.23175

3) Template-based protein structure modeling using the RaptorX web server
Källberg M, et al. Nat Protoc. 2012 Jul 19;7(8):1511-22. PMID: 22814390 PMCID: PMC4730388 DOI: 10.1038/nprot.2012.085

4) Enhanced fold recognition using efficient short fragment clustering
Krissinel E. J Mol Biochem. 2012;1(2):76-85. PMID: 27882309 PMCID: PMC5117261

5) Overview of the CCP4 suite and current developments
Winn MD et al. Acta Crystallogr D Biol Crystallogr. 2011 Apr;67(Pt 4):235-42. PMID: 21460441 PMCID: PMC3069738 DOI: 10.1107/S0907444910045749

### HOWTO
1) Predict 3D structures with RaptorX/raptorX.pl
cd RAPTORX_INSTALLATION_DIRECTORY/
raptorx.pl -t 10 -k 2 -i ~/FASTA/ -o ~/3D_predictions/

2) Download PDB files from RCSB ## see PDB_update.sh
rsync -rlpt -v -z --delete --port=33444 \
rsync.rcsb.org::ftp_data/structures/divided/pdb/ /path/to/PDB/

3) Create a tab-delimited list of PDB files and their titles from the downloaded RCSB gzipped files
PDB_headers.pl -p /path/to/PDB/ -o /path/to/PDB_titles.tsv

4) Create a GESAMT database
run_GESAMT.pl -cpu 10 -make -arch /path/to/GESAMT_ARCHIVE -pdb /path/to/PDB/	## CREATE DB
run_GESAMT.pl -cpu 10 -update -arch /path/to/GESAMT_ARCHIVE -pdb /path/to/PDB/	## UPDATE DB

5) Query the GESAMT database for structural homology
run_GESAMT.pl -cpu 10 -query -arch /path/to/GESAMT_ARCHIVE -input /path/to/*.pdb -o /path/to/RESULTS_FOLDER -mode normal

6) Parse the GESAMT output to add definitions/products to the PDB matches found
descriptive_GESAMT_matches.pl -t /path/to/PDB_titles.tsv -m *.gesamt -q 0.3 -o /path/to/GESAMT.matches 

### NOTES 
1. Single fasta files for structure prediction with raptorx.pl can be created with split_Fasta.pl
2. Files can be renamed using regular expressions with rename_files.pl
3. RCSB PDB files can be split per chain with split_PDB.pl
