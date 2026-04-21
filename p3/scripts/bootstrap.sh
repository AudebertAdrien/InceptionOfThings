#!/bin/bash
set -e

K3D_CLUSTER_NAME="iot-cluster"
USER_HOME="/home/vagrant"

echo "=================================================="
echo "         System Setup & Docker Install            "
echo "=================================================="

sudo apt update && sudo apt install -y curl ca-certificates
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker vagrant

echo "=================================================="
echo "         Kubernetes & K3d Installation           "
echo "=================================================="

if [ ! -f /usr/local/bin/kubectl ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

if ! k3d cluster list | grep -q "$K3D_CLUSTER_NAME"; then
  k3d cluster create "$K3D_CLUSTER_NAME" --port "8000:80@loadbalancer" --wait
fi

mkdir -p "$USER_HOME/.kube"
k3d kubeconfig get "$K3D_CLUSTER_NAME" >"$USER_HOME/.kube/config"
chown -R vagrant:vagrant "$USER_HOME/.kube"
chmod 600 "$USER_HOME/.kube/config"

if ! grep -q "KUBECONFIG" /home/vagrant/.bashrc; then
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >>/home/vagrant/.bashrc
fi

echo "=================================================="
echo "               Argo CD Deployment                 "
echo "=================================================="

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

kubectl apply -f /share/confs/platform/argocd-params-cm.yaml
kubectl apply -f /share/confs/platform/argocd-ing.yaml

kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

kubectl apply -f /share/confs/platform/argocd-app.yaml

echo "=================================================="
echo "             Installation Complete                "
echo "=================================================="

echo -n "Argo CD 'admin' Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

