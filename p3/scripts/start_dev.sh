#!/bin/bash
sudo k3d cluster create --config ./confs/config_k3d.yaml
sudo kubectl create namespace dev
sudo kubectl -n argocd apply -f ./confs/config_argocd.yaml