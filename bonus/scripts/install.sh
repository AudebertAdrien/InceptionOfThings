#!/bin/bash
sudo apt update && sudo apt install -y docker.io curl wget snapd
curl -sfL https://get.k3s.io | sh -
wget -q -O - https://raw.githubusercontent.com/rancher/k3d/master/install.sh | bash
sudo snap install helm --classic