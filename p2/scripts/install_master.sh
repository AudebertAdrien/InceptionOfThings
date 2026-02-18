#!/bin/bash
set -e

sudo apt update && sudo apt install -y curl

sudo mkdir -p /etc/rancher/k3s
sudo cp /share/confs/k3s_config.yaml /etc/rancher/k3s/config.yaml

curl -sfL https://get.k3s.io | sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  echo "Waiting for the token..."
  sleep 1
done

sudo cat /var/lib/rancher/k3s/server/node-token >/share/k3s_token.txt

mkdir -p /home/vagrant/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube

if ! grep -q "KUBECONFIG" /home/vagrant/.bashrc; then
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >>/home/vagrant/.bashrc
fi

until sudo kubectl get nodes >/dev/null 2>&1; do
  echo "Waiting for API Server..."
  sleep 2
done

echo "Waiting for system pods to be ready..."
sudo kubectl wait --for=condition=Ready node/aaudebers --timeout=90s

sudo kubectl apply -f /share/confs/app1.yaml
sudo kubectl apply -f /share/confs/app2.yaml
sudo kubectl apply -f /share/confs/app3.yaml
sudo kubectl apply -f /share/confs/ingress.yaml

echo "Deployment finished!"
