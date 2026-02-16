#!/bin/bash

sudo apt update && sudo apt install -y curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-name aaudeberS --node-ip 192.168.56.110" sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  echo "Waiting for the token..."
  sleep 1
done

sudo k3s kubectl get nodes -o wide

sudo cat /var/lib/rancher/k3s/server/node-token >/vagrant/k3s_token.txt
