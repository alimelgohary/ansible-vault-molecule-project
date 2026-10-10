### This script is to run the project on killerkoda temporary ubuntu environment
```
#!/bin/bash
set -euo pipefail

# Install dependencies
sudo apt update && \
sudo apt install -y ansible python3-hvac python3.12-venv docker.io && \
sudo systemctl start docker


# Clone the repo
git clone https://github.com/alimelgohary/ansible-vault-molecule-project
cd ansible-vault-molecule-project

# Set auto pull (You won't need it, it's for me for testing)
nohup bash -c 'while true; do git pull origin master > /dev/null 2>&1; sleep 5; done' > /dev/null 2>&1 &

# Install needed ansible collections
ansible-galaxy collection install -r requirements.yml


# ========= Molecule Setup & Test =========

# Create a venv for molecule packages
python3 -m venv molecule-env
source molecule-env/bin/activate
pip install molecule molecule-plugins[docker]

# Deactive the venv
deactivate

# ========= Test on Inventory =========

# Create an inventory sample host in a container
sudo docker run -d \
  --name pg_test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  geerlingguy/docker-ubuntu2204-ansible@sha256:7c37bfb098b8f52d18ee730a65f946a2535acab19b6f491418c2ed788d51974a

# Initialize hashicorp vault and Unseal
./00-initialize-vault.sh

# Execute and get RoleID, SecretID in env 
source 01-setup-vault.sh 

ansible-playbook -i inventory.ini playbook.yml

 
```
