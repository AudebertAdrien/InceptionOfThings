#!/bin/bash

K3D_CLUSTER_NAME="iot-cluster"
USER_HOME="/home/vagrant"

echo "=================================================="
echo "         System Setup & Docker Install            "
echo "=================================================="

sudo apt update
sudo apt install -y ca-certificates curl git
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
echo "         Kubernetes & Helm & K3d Installation           "
echo "=================================================="

# kubectl
if [ ! -f /usr/local/bin/kubectl ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

# Helm
if [ ! -f /usr/local/bin/helm ]; then
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash get_helm.sh
  rm get_helm.sh
fi

# K3d
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

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

echo "=================================================="
echo "               GitLab Deployment (Helm)           "
echo "=================================================="

helm repo add gitlab https://charts.gitlab.io/
helm repo update

helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --create-namespace \
  --timeout 900s \
  -f /share/confs/gitlab/gitlab-values.yaml

echo "Waiting for GitLab Webservice and Toolbox to be ready (This will take a long time)..."

while ! kubectl get deployment gitlab-webservice-default -n gitlab -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' | grep -q "True"; do
  sleep 20
done

while ! kubectl get deployment gitlab-toolbox -n gitlab -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' | grep -q "True"; do
  sleep 20
done

echo "=================================================="
echo "         GitLab Automation (Project & Push)       "
echo "=================================================="

if ! grep -q "gitlab.iot.local" /etc/hosts; then
  echo "127.0.0.1 gitlab.iot.local" | sudo tee -a /etc/hosts
fi


echo "Waiting for GitLab web interface HTTP 200..."
while ! curl -s -o /dev/null -w "%{http_code}" http://gitlab.iot.local:8080 | grep -qE "200|302"; do
  sleep 10
done

GITLAB_TOOLBOX_POD=$(kubectl get pods -n gitlab -l app=toolbox -o jsonpath='{.items[0].metadata.name}')

echo "Creating public project and Access Token via Rails Runner..."
kubectl exec -n gitlab $GITLAB_TOOLBOX_POD -- gitlab-rails runner "
user = User.find_by_username('root');

Project.create(name: 'iot-project', path: 'iot-project', namespace_id: user.namespace.id, visibility_level: 20, creator: user) unless Project.find_by_path('iot-project');

unless user.personal_access_tokens.find_by_name('AutoToken')
  token = user.personal_access_tokens.build(scopes: ['api', 'write_repository'], name: 'AutoToken', expires_at: 365.days.from_now);
  token.set_token('glpat-VagrantToken1234');
  token.save!;
  puts 'Token created successfully.';
else
  puts 'Token already exists. Skipping creation.';
end
"

echo "Pushing configuration to local GitLab..."
cd /share/confs

git config --global user.email "vagrant@iot.local"
git config --global user.name "Vagrant Administrator"

git init
git checkout -b main 2>/dev/null || true
git add apps/
git commit -m "Automated initial push for GitOps" || true

git remote remove origin 2>/dev/null || true
git remote add origin http://root:glpat-VagrantToken1234@gitlab.iot.local:8080/root/iot-project.git
git push -u origin main

echo "=================================================="
echo "               Argo CD Deployment (Helm)          "
echo "=================================================="

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f /share/confs/argocd/argocd-values.yaml

echo "Waiting for Argo CD Server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

kubectl apply -f /share/confs/argocd/argocd-app.yaml

echo "=================================================="
echo "             Installation Complete                "
echo "=================================================="

echo -n "Argo CD 'admin' Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

echo -n "Gitlab 'root' Password: "
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 -d
echo
