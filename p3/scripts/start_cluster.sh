#!/bin/bash
sudo k3d cluster create cluster1
sudo kubectl create namespace argocd
sudo kubectl create namespace dev
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 20
sudo kubectl get all -n argocd
sudo kubectl port-forward svc/argocd-server -n argocd 443:443
sudo kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

