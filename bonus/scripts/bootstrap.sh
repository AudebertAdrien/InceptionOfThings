#!/bin/bash
set -e

K3D_CLUSTER_NAME="iot-cluster"
USER_HOME="/home/vagrant"

echo "=================================================="
echo "         System Setup & Docker Install            "
echo "=================================================="

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

echo "=================================================="
echo "         Kubernetes Tools & K3d Cluster           "
echo "=================================================="

if [ ! -f /usr/local/bin/kubectl ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

if ! k3d cluster list | grep -q "$K3D_CLUSTER_NAME"; then
  k3d cluster create "$K3D_CLUSTER_NAME" --port "8080:80@loadbalancer" --wait
fi

mkdir -p "$USER_HOME/.kube"
k3d kubeconfig get "$K3D_CLUSTER_NAME" >"$USER_HOME/.kube/config"
chown -R vagrant:vagrant "$USER_HOME/.kube"
chmod 600 "$USER_HOME/.kube/config"

if ! grep -q "KUBECONFIG" /home/vagrant/.bashrc; then
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >>/home/vagrant/.bashrc
fi

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

echo "=================================================="
echo "               GitLab Deployment                  "
echo "=================================================="

kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f /share/confs/gitlab/gitlab-dep.yaml
kubectl apply -f /share/confs/gitlab/gitlab-svc.yaml
kubectl apply -f /share/confs/gitlab/gitlab-ing.yaml

echo "Waiting for GitLab to be ready..."

kubectl rollout restart deployment/gitlab -n gitlab
kubectl rollout status deployment/gitlab -n gitlab --timeout=800s

echo "=================================================="
echo "         GitLab Automation (Project & Push)       "
echo "=================================================="

sudo apt-get install -y git

if ! grep -q "gitlab.iot.local" /etc/hosts; then
  echo "127.0.0.1 gitlab.iot.local" | sudo tee -a /etc/hosts
fi

echo "Waiting for GitLab web interface to fully boot (can take a few minutes)..."
while ! curl -s -o /dev/null -w "%{http_code}" http://gitlab.iot.local:8080 | grep -qE "200|302"; do
  sleep 10
done

GITLAB_POD=$(kubectl get pods -n gitlab -l app.kubernetes.io/name=gitlab -o jsonpath='{.items[0].metadata.name}')

echo "Creating public project and Access Token via Rails Runner..."
kubectl exec -n gitlab $GITLAB_POD -- gitlab-rails runner "
user = User.find_by_username('root');
Project.create(name: 'iot-project', path: 'iot-project', namespace_id: user.namespace.id, visibility_level: 20, creator: user) unless Project.find_by_path('iot-project');
token = user.personal_access_tokens.build(scopes: ['api', 'write_repository'], name: 'AutoToken', expires_at: 365.days.from_now);
token.set_token('glpat-VagrantToken1234');
token.save!
"

echo "Pushing configuration to local GitLab..."
cd /share/

git config --global user.email "vagrant@iot.local"
git config --global user.name "Vagrant Administrator"

git init
git checkout -b main 2>/dev/null || true
git add .
git commit -m "Automated initial push for GitOps" || true

git remote remove origin 2>/dev/null || true
git remote add origin http://root:glpat-VagrantToken1234@gitlab.iot.local:8080/root/iot-project.git
git push -u origin main

echo "=================================================="
echo "               Argo CD Deployment                 "
echo "=================================================="

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side

echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

kubectl apply -f /share/confs/argocd/argocd-params-cm.yaml
kubectl apply -f /share/confs/argocd/argocd-ing.yaml

echo "Restarting Argo CD server..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=60s

kubectl apply -f /share/confs/argocd/argocd-app.yaml

echo "=================================================="
echo "             Installation Complete                "
echo "=================================================="

echo -n "Argo CD "admin" Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

echo -n "Gitlab "root" Password: "
kubectl exec -n gitlab -it $(kubectl get pods -n gitlab -l app.kubernetes.io/name=gitlab -o jsonpath='{.items[0].metadata.name}') -- grep 'Password:' /etc/gitlab/initial_root_password
