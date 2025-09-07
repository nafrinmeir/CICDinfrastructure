#!/bin/bash
set -e

# -----------------------------------------------
# Helper function to safely upgrade system
# -----------------------------------------------
safe_upgrade() {
    echo "[*] Updating package lists..."
    sudo apt-get update -y

    echo "[*] Trying full upgrade (including linux-firmware)..."
    if ! sudo apt-get upgrade -y; then
        echo "[!] Upgrade failed due to linux-firmware. Skipping it..."
        sudo apt-mark hold linux-firmware
        sudo apt-get upgrade -y
        echo "[*] linux-firmware is on hold. You can upgrade it later with:"
        echo "    sudo apt-mark unhold linux-firmware && sudo apt-get upgrade -y"
    fi
}

echo "[1/12] עדכון מערכת והגנה על linux-firmware"
safe_upgrade

echo "[2/12] התקנת Docker"
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

echo "[3/12] התקנת Docker Compose"
DOCKER_COMPOSE_VERSION="v2.29.2"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

echo "[4/12] התקנת Kubernetes (kubeadm / kubelet / kubectl)"
# הסרת ריפו ישן אם קיים
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# הוספת מפתח רשמי ו-repo חדש
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[5/12] יצירת קלאסטר K8s בסיסי (Single-Node)"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 || true
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "[6/12] התקנת Terraform"
TERRAFORM_VERSION="1.9.5"
curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o terraform.zip
sudo apt-get install -y unzip
unzip terraform.zip
sudo mv terraform /usr/local/bin/
rm terraform.zip
terraform -version

echo "[7/12] התקנת Ansible"
sudo apt-get install -y ansible
ansible --version

echo "[8/12] התקנת Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

echo "[9/12] התקנת Jenkins (דרך Helm)"
helm repo add jenkins https://charts.jenkins.io
helm repo update
kubectl create namespace jenkins || true
helm upgrade --install jenkins jenkins/jenkins --namespace jenkins

echo "[10/12] התקנת ArgoCD (דרך Helm)"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd || true
helm upgrade --install argocd argo/argo-cd --namespace argocd

echo "[11/12] התקנת Grafana (דרך Helm)"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace grafana || true
helm upgrade --install grafana grafana/grafana --namespace grafana

echo "[12/12] התקנת Trivy"
sudo apt-get install -y wget
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb stable main | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update -y
sudo apt-get install -y trivy
trivy --version

echo "✅ ההתקנה הסתיימה בהצלחה!"
