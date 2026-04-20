#!/bin/bash
# Create cluster
if k3d cluster list cluster1 &> /dev/null; then
	echo "Cluster already exists"
else
	sudo k3d cluster create cluster1 --config ./confs/config_k3d.yaml
fi
if sudo kubectl create namespace argocd; then
	echo "Namespace argocd created"
	# Setup argocd
	sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	sudo kubectl apply -f ./confs/config_cluster.yaml
	sudo kubectl rollout restart deployment argocd-server -n argocd
	sleep 10
	sudo kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
	sudo kubectl get all -n argocd
fi
# Deploy app with config files
sudo kubectl create namespace dev
sudo kubectl apply -f ./confs/config_cluster.yaml
sudo kubectl -n argocd apply -f ./confs/config_argocd.yaml
# Get password for argocd admin user :
# For linux
sudo kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# For powershell
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) };