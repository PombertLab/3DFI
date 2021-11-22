## On Fedora 34
##### Installing Aria2, Conda and Docker #####
sudo dnf install aria2 conda docker

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

## Installing NVIDIA docker container
# On Fedora 34 (https://www.if-not-true-then-false.com/2020/install-nvidia-container-toolkit-on-fedora/)
sudo wget -O /etc/yum.repos.d/inttf.repo https://rpms.if-not-true-then-false.com/inttf.repo
sudo dnf install nvidia-docker2

# On Fedora 35 (https://blog.shawonashraf.com/nvidia-podman-fedora-34)
distribution=rhel8.3
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.repo | \
sudo tee /etc/yum.repos.d/nvidia-container-runtime.repo
sudo dnf install nvidia-container-runtime


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
## Add user(s) to docker group

## Testing capabilities with sample
docker run \
	--privileged \
	--gpus all \
	--rm nvcr.io/nvidia/k8s/cuda-sample:nbody nbody \
	-benchmark \
	-numbodies=512000
