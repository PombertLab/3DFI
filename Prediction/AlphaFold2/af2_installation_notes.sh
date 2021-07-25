#!/usr/bin/perl

##### On Fedora 33/34 (tested with NVIDIA RTX A6000)
##### Installing Docker - https://docs.docker.com/engine/install/fedora/ #####
## Removing old versions
sudo dnf remove docker \
	docker-client \
	docker-client-latest \
	docker-common \
	docker-latest \
	docker-latest-logrotate \
	docker-logrotate \
	docker-selinux \
	docker-engine-selinux \
	docker-engine

## Enabling repositories
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager \
	--add-repo \
	https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf config-manager --set-enabled docker-ce-nightly
sudo dnf config-manager --set-enabled docker-ce-test

## Installing docker
sudo dnf install docker-ce docker-ce-cli containerd.io

## Starting Docker / enabling at boot
sudo systemctl start docker
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

## Testing docker
sudo docker run hello-world

## Creating docker group + add user(s) to it + activate docker group changes
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

## Installing NVIDIA docker container - https://www.if-not-true-then-false.com/2020/install-nvidia-container-toolkit-on-fedora/
sudo wget -O /etc/yum.repos.d/inttf.repo https://rpms.if-not-true-then-false.com/inttf.repo
sudo dnf install nvidia-docker2

## Modifying configuration file
sudo nano /etc/nvidia-container-runtime/config.toml
# Remove comment from 'no-cgroups = false' and change to 'no-cgroups = true'
# Under [nvidia-container-runtime]
# Remove comment (enable): debug = "/var/log/nvidia-container-runtime.log"

## Restarting Docker and checking that nvidia configuration is working
systemctl restart docker
nvidia-container-cli info
docker run \
	--privileged \
	--gpus all \
	--rm nvidia/cuda:11.1-base \
	nvidia-smi

## Make sure to add --privileged to prevent 'Failed to initialize NVML: Unknown Error'
## Add docker users to docker group

## Testing capabilities with sample
docker run \
	--privileged \
	--gpus all \
	--rm nvcr.io/nvidia/k8s/cuda-sample:nbody nbody \
	-benchmark \
	-numbodies=512000



##### Installing AlphaFold2 - https://github.com/deepmind/alphafold #####
## Setting up installation and databases directory
export INST_ROOT=/media/Data_1/opt/
export AF_DB=/media/FatCat/databases/alphafold_db

mkdir -p $INST_ROOT $AF_DB
cd $INST_ROOT;
git clone https://github.com/deepmind/alphafold.git
cd alphafold
export ALPHA_HOME=$(pwd)



##### Downloading databases (2.2 Tb uncompressed); very long download #####
## Installing aria2
sudo dnf install aria2

## To speed up things, add -x10 to the individual shell scripts:
## e.g. nano $AF_DIR/scripts/download_bfd.sh
## aria2c -x10 "${SOURCE_URL}" --dir="${ROOT_DIR}"
## -x, --max-connection-per-server=NUM The maximum number of connections to one server for each download. Possible Values: 1-16
$ALPHA_HOME/scripts/download_all_data.sh $AF_DB

## Testing docker for Alphafold
docker run \
	--rm \
	--gpus all \
	nvidia/cuda:11.0-base \
	nvidia-smi

## If 'Failed to initialize NVML: Unknown Error':
ls -l /dev/nvidia*
# crw-rw-rw- 1 root root  195,   0 Jul 23 13:32 /dev/nvidia0
# crw-rw-rw- 1 root root  195, 255 Jul 23 13:32 /dev/nvidiactl
# crw-rw-rw- 1 root root  195, 254 Jul 23 13:32 /dev/nvidia-modeset
# crw-rw-rw- 1 root root  510,   0 Jul 23 13:32 /dev/nvidia-uvm
# crw-rw-rw- 1 root root  510,   1 Jul 23 13:32 /dev/nvidia-uvm-tools
## Add all nvidia devices; nvidia0, nvidia1 (if present) and so forth
docker run \
	--rm \
	--gpus all \
	--device /dev/nvidia0 \
	--device /dev/nvidiactl \
	--device /dev/nvidia-uvm \
	--device /dev/nvidia-uvm-tools \
	nvidia/cuda:11.0-base nvidia-smi

## If 'Failed to initialize NVML: Unknown Error' remains: add --privileged (https://docs.docker.com/engine/reference/run/)
## Not recommended because it gives extended privileges to the container 
docker run \
	--rm \
	--privileged \
	--gpus all \
	nvidia/cuda:11.0-base \
	nvidia-smi



##### Building the docker image #####
##
## The default docker image uses cuda 11.0 which works for cuda compute capability of <= 8.0.
## Nvidia RTX 3000+ series (Cuda compute 8.6) need 11.1+
## Must update Dockerfile accordingly
## 
nano $ALPHA_HOME/docker/Dockerfile

# ARG CUDA=11.0 -> ARG CUDA=11.1
# FROM nvidia/cuda:${CUDA}-base -> FROM nvidia/cuda:${CUDA}-devel
#
# Under Install conda packages:
# cudatoolkit==${CUDA}.3 -> cudatoolkit-dev==${CUDA}.1
# if absent add: cudnn \
#
# e.g.
# RUN conda update -qy conda \
#     && conda install -y -c conda-forge \
#       openmm=7.5.1 \
#       cudatoolkit-dev==${CUDA}.1 \
#       cudnn \
#       pdbfixer \
#       pip

## Changing the default database location and output directory in run_docker.py
## with desired locations

## e.g.
nano $ALPHA_HOME/docker/run_docker.py

#### USER CONFIGURATION ####

# Set to target of scripts/download_all_databases.sh
# DOWNLOAD_DIR = 'SET ME' -> DOWNLOAD_DIR = '/media/FatCat/databases/alphafold_db'

# Name of the AlphaFold Docker image.
# docker_image_name = 'alphafold'

# Path to a directory that will store the results.
# output_dir = '/tmp/alphafold' -> '/media/FatCat/results/alphafold'


## NOTE: If the 'Failed to initialize NVML: Unknown Error' shows up when running docker, we can:
## add 'privileged=True, to container = client.containers.run();
# e.g.
nano $ALPHA_HOME/docker/run_docker.py

# container = client.containers.run(
#       image=docker_image_name,
#       command=command_args,
#       runtime='nvidia' if FLAGS.use_gpu else None,
#       privileged=True,
#       remove=True,
#       detach=True,
#       mounts=mounts,
#       environment={
#           'NVIDIA_VISIBLE_DEVICES': FLAGS.gpu_devices,
#           # The following flags allow us to make predictions on proteins that
#           # would typically be too long to fit into GPU memory.
#           'TF_FORCE_UNIFIED_MEMORY': '1',
#           'XLA_PYTHON_CLIENT_MEM_FRACTION': '4.0',
#       })


## Once the Dockerfile and run_docker.py are configured
cd $ALPHA_HOME
docker build -f docker/Dockerfile -t alphafold .
pip3 install -r docker/requirements.txt

## Creating environment variables
export RESULTS_DIR=/media/FatCat/results/alphafold
echo "export ALPHA_HOME=$ALPHA_HOME" >> ~/.bashrc
echo "export ALPHA_OUT=$RESULTS_DIR" >> ~/.bashrc
