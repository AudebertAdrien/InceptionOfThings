#!/bin/bash
sudo k3d cluster create cluster1
sudo kubectl create namespace dev
sudo kubectl -n dev apply -f ./confs/config_argocd.yaml