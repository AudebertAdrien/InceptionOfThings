#!/bin/bash
set -e

sudo apt update && sudo apt install -y curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-name aaudeberS --node-ip 192.168.56.110 --bind-address 192.168.56.110 --advertise-address 192.168.56.110" sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  echo "Waiting for the token..."
  sleep 1
done

mkdir -p /share/confs
sudo cat /var/lib/rancher/k3s/server/node-token >/share/confs/k3s_token.txt

mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube

if ! grep -q "KUBECONFIG" /home/vagrant/.bashrc; then
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >>/home/vagrant/.bashrc
  echo "KUBECONFIG exported to .bashrc"
fi

sudo kubectl get nodes
