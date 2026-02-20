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
	sleep 40
	sudo kubectl get all -n argocd
	sudo kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "nodePort": 30001}]}}'
fi
# Deploy app with config files
sudo kubectl create namespace dev
sudo kubectl -n argocd apply -f ./confs/config_argocd.yaml
# Get password for argocd admin user :
# For linux
sudo kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# For powershell
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) };