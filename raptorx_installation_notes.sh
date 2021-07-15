#!/usr/bin/bash
# A simple shell script to assist in the installation of RaptorX

##### Tested as an Ubuntu 18.04 LTS VM on VMware workstation (windows) && KVM (Fedora)

##### Installing MODELLER https://salilab.org/modeller/download_installation.html
# Register to get a license key from https://salilab.org/modeller/registration.html
# Replace XXXXX by license and modeller_10.1-1_amd64.deb by appropriate version
LICENSE=XXXXX
MODELLER=modeller_10.1-1_amd64.deb
sudo env KEY_MODELLER=$LICENSE dpkg -i $MODELLER

## On RedHat/Fedora
# MODELLER=modeller-10.1-1.x86_64.rpm
# sudo env KEY_MODELLER=$LICENSE rpm -Uvh $MODELLER

##### Installing RaptorX 
## http://raptorx.uchicago.edu/download/
## RaptorX installation files required:
# CNFsearch1.66_complete.zip
# nr70.tar.gz
# nr90.tar.gz
# TPL_BC40_20210204.tar.gz
# TPL_Remain_20210204.tar.gz
# TemplateLists_20210204.tar.gz
# pdb_BC40_20210204.tar.gz
# pdb_Remain_20210204.tar.gz
# CAL_TGT.tar.gz
# CAL_TPL.tar.gz

## Path where RaptorX will be installed; replace with desired location
RX=/opt/RaptorX/

## Path where RaptorX databases will be installed; replace with desired location
## Note: ~ 80 Gb of disk space will be required
DB=/opt/RaptorX_databases/

## Path to downloaded RaptorX installation files; replace with proper location
FILES=~/Downloads/

## Creating installation directories
mkdir $RX $DB
## sudo -s mkdir $RX $DB
## if $RX $DB located in permission-restricted location:


##### RaptorX (CNFsearch1.66_complete.zip)
cp $FILES/CNFsearch1.66_complete.zip $RX
cd $RX
unzip CNFsearch1.66_complete.zip
mv CNFsearch1.66_complete/* $RX/
rmdir $RX/CNFsearch1.66_complete
mkdir $RX/tmp
chmod -R 775 $RX
./setup.pl
## setup.pl from the CNFsearch1.66_complete package replaces the /home/wangsheng/CNFsearch_Release/CNFsearch1.6
## hard links from its shell and Perl scripts by the current installation directory

### Creating symlink to databases
rm -R $RX/databases
ln -s $DB $RX/databases

### Decompressing databases
cp $FILES/*.tar.gz $DB
## mv $FILES/*.tar.gz $DB
## use either cp or mv to keep (copy) or delete (move) the downloaded files in $FILES
cd $DB
for file in *.tar.gz; do tar -zxvf $file; done
mkdir NR_new
mv nr?0* NR_new/
mv TPL_BC40 TPL_BC100
mv pdb_BC40 pdb_BC100
## Creating the reference_tpl_list
ls CAL_TPL/*.tpl | awk -F/ '{print $2}' | awk -F\. '{print $1}' > reference_tpl_list
## Deleting references to corrupted 6f45D.tpl file
rm -f $DB/TPL_BC100/6f45D.tpl
for v in {40,70,90,100}; do
  sed -i '/6f45D/d' $DB/bc${v}_list;
  sed -i '/6f45D/d' $DB/bc${v}_map;
done
## Deleting tar files
rm -f *.tar.gz

### Adding PATH variables to user bashrc
echo "export PATH=$PATH:$RX" >> ~/.bashrc
echo "export RAPTORX_PATH=$RX" >> ~/.bashrc

### Checking for $PYTHONHOME and python2.7, python, or python3
if [ -n "$PYTHONHOME" ];
    then
    echo "Found PYTHONHOME set to $PYTHONHOME, leaving it as is";
    else
        if [ -n "$(which python2.7)" ];
            then
                echo "found python2.7 = $(which python2.7)";
                PYTHONHOME=$(which python2.7 | sed 's/\/python.*//');
                echo "setting PYTHONHOME to $PYTHONHOME";
                echo "export PYTHONHOME=$PYTHONHOME" >> ~/.bashrc
        elif [ -n "$(which python)" ];
            then
                echo "found python = $(which python)";
                PYTHONHOME=$(which python | sed 's/\/python.*//');
                echo "setting PYTHONHOME to $PYTHONHOME";
                echo "export PYTHONHOME=$PYTHONHOME" >> ~/.bashrc
        elif [ -n "$(which python3)" ];
            then
                echo "found python3 = $(which python3)";
                PYTHONHOME=$(which python3 | sed 's/\/python.*//');
                echo "setting PYTHONHOME to $PYTHONHOME";
                echo "export PYTHONHOME=$PYTHONHOME" >> ~/.bashrc
        else
            echo "Python not detected. Please check manually"
        fi
fi
