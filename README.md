### This script is to run the project on killerkoda temporary ubuntu environment
```
#!/bin/bash
set -euo pipefail

# Install dependencies and create an inventory sample host in a container
sudo apt update && \
sudo apt install -y ansible python3-hvac docker.io && \
sudo systemctl start docker && \
sudo docker run -d \
  --name pg_test \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  geerlingguy/docker-ubuntu2204-ansible

# Clone the repo
git clone https://github.com/alimelgohary/ansible-vault-molecule-project
cd ansible-vault-molecule-project

# Install needed ansible collections
ansible-galaxy collection install -r requirements.yml

# Set auto pull (You won't need it, it's for me for testing)
while true
do 
  git pull origin master > /dev/null 2>&1
  sleep 5
done &
```
