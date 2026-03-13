#!/bin/bash

# Install Docker
sudo apt update
sudo apt install -y ca-certificates curl
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

# Install kubectl
if [ ! -f /usr/local/bin/kubectl ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

# Install K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

if ! k3d cluster list | grep -q "dev-cluster"; then
  k3d cluster create dev-cluster --port "8080:80@loadbalancer" --wait
fi

mkdir -p /home/vagrant/.kube
k3d kubeconfig get dev-cluster >/home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
chmod 600 /home/vagrant/.kube/config

if ! grep -q "KUBECONFIG" /home/vagrant/.bashrc; then
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >>/home/vagrant/.bashrc
fi

kubectl create namespace argocd
kubectl create namespace dev

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

kubectl apply -n argocd -f /share/confs/application.yaml
kubectl apply -n dev -f /share/confs/app-ingress.yaml
kubectl apply -n argocd -f /share/confs/argocd-ingress.yaml
kubectl rollout restart deployment argocd-server -n argocd
