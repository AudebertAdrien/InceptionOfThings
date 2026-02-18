#!/bin/bash
sudo apt update && sudo apt install -y curl
sudo mkdir -p /etc/rancher/k3s
sudo cp /vagrant/	config.yaml /etc/rancher/k3s/config.yaml
curl -sfL https://get.k3s.io | sh -
sleep 5
sudo k3s kubectl get nodes
sleep 10
sudo kubectl apply -f /vagrant/deployment.yaml
sleep 20
sudo kubectl get all