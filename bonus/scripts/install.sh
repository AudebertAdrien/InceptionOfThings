#!/bin/bash

K3D_CLUSTER_NAME="iot-cluster"
USER_HOME="/home/vagrant"

sudo apt update && sudo apt install -y curl wget
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

if [ ! -f /usr/local/bin/kubectl ]; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
fi

sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

mkdir -p "$USER_HOME/.kube"
k3d kubeconfig get "$K3D_CLUSTER_NAME" >"$USER_HOME/.kube/config"
chown -R vagrant:vagrant "$USER_HOME/.kube"
chmod 600 "$USER_HOME/.kube/config"

if ! k3d cluster list | grep -q "$K3D_CLUSTER_NAME"; then
  k3d cluster create $K3D_CLUSTER_NAME --config /share/confs/config_k3d.yaml
fi

echo "=================================================="
echo "               GitLab Deployment (Helm)           "
echo "=================================================="

if kubectl create namespace gitlab; then
	echo "Namespace gitlab created"
	helm repo add gitlab https://charts.gitlab.io/
	helm repo update
	helm install gitlab gitlab/gitlab -n gitlab -f /share/confs/config_gitlab.yaml --set global.edition=ce
	kubectl rollout status deployment/gitlab-webservice-default -n gitlab --timeout=900s
	kubectl rollout status deployment/gitlab-toolbox -n gitlab --timeout=900s
	kubectl get all -n gitlab
fi

echo "=================================================="
echo "         GitLab Automation (Project & Push)       "
echo "=================================================="

if ! grep -q "gitlab.local" /etc/hosts; then
  echo "127.0.0.1 gitlab.local" | sudo tee -a /etc/hosts
fi

echo "Waiting for GitLab web interface HTTP 200..."
while ! curl -s -o /dev/null -w "%{http_code}" http://gitlab.local:8000 | grep -qE "200|302"; do
  sleep 10
done

GITLAB_TOOLBOX_POD=$(kubectl get pods -n gitlab -l app=toolbox -o jsonpath='{.items[0].metadata.name}')

echo "Creating public project and Access Token via Rails Runner..."
kubectl exec -n gitlab $GITLAB_TOOLBOX_POD -- gitlab-rails runner "
user = User.find_by_username('root');
Project.create(name: 'iot-project', path: 'iot-project', namespace_id: user.namespace.id, visibility_level: 20, creator: user) unless Project.find_by_path('iot-project');
token = user.personal_access_tokens.build(scopes: ['api', 'write_repository'], name: 'AutoToken', expires_at: 365.days.from_now);
token.set_token('glpat-VagrantToken1234');
token.save!
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
git remote add origin http://root:glpat-VagrantToken1234@gitlab.local:8000/root/iot-project.git
git push -u origin main

echo "=================================================="
echo "               Argo CD Deployment (Helm)          "
echo "=================================================="

if sudo kubectl create namespace argocd; then
	echo "Namespace argocd created"
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update
    kubectl create namespace dev
	helm install argocd argo/argo-cd -n argocd -f /share/confs/config_argocd.yaml
	kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
	kubectl get all -n argocd
fi

kubectl apply -f /share/confs/config_ingress.yaml
kubectl -n argocd apply -f /share/confs/config_app.yaml

echo "=================================================="
echo "             Installation Complete                "
echo "=================================================="

echo -n "Argo CD 'admin' Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

echo -n "Gitlab 'root' Password: "
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 -d
echo
