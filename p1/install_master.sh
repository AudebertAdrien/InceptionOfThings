#!/bin/bash

sudo apt update && sudo apt install -y curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-name wilS --node-ip 192.168.56.110" sh -

sleep 5

sudo k3s kubectl get nodes -o wide

sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/k3s_token.txt
