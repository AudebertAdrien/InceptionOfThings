#!/bin/bash
if k3d cluster list cluster1 &> /dev/null; then
	echo "Cluster already exists"
else
	sudo k3d cluster create cluster1 --config ./confs/config_k3d.yaml
fi
if sudo kubectl create namespace gitlab; then
	echo "Namespace gitlab created"
	sudo helm repo add gitlab https://charts.gitlab.io/
	sudo helm repo update
	sudo helm install gitlab gitlab/gitlab -n gitlab -f ./confs/config_gitlab.yaml --set global.edition=ce
	sleep 500
	sudo kubectl get all -n gitlab
fi
if sudo kubectl create namespace argocd; then
	echo "Namespace argocd created"
	sudo helm repo add argo https://argoproj.github.io/argo-helm
	sudo helm repo update
	sudo helm install argocd argo/argo-cd -n argocd -f ./confs/config_argocd.yaml
	sleep 40
	sudo kubectl get all -n argocd
fi
# Deploy app with config files
sudo kubectl create namespace dev
sudo kubectl apply -f ./confs/config_ingress.yaml