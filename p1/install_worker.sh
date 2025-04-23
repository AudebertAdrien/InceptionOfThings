#!/bin/bash

sudo apt update && sudo apt install -y curl

TOKEN=$(cat /vagrant/k3s_token.txt)

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=${TOKEN} INSTALL_K3S_EXEC="--node-name wilSW --node-ip 192.168.56.111" sh -
