#!/bin/bash
set -e

sudo apt update && sudo apt install -y curl

while [ ! -f /share/confs/k3s_token.txt ]; do
  echo "Waiting for master token in /share/confs..."
  sleep 2
done

TOKEN=$(cat /share/confs/k3s_token.txt)

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=${TOKEN} INSTALL_K3S_EXEC="--node-name aaudeberSW --node-ip 192.168.56.111" sh -
