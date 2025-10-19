#!/bin/bash
set -e

echo "======================================"
echo "ArgoCD Bootstrap Script"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Make sure your kubeconfig is properly configured"
    exit 1
fi

echo -e "${GREEN}✓${NC} Cluster connection verified"

# Create ArgoCD namespace
echo ""
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓${NC} Namespace created"

# Add ArgoCD Helm repository
echo ""
echo "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
echo -e "${GREEN}✓${NC} Helm repository added"

# Install ArgoCD
echo ""
echo "Installing ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --version 7.7.0 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true \
  --wait \
  --timeout 10m

echo -e "${GREEN}✓${NC} ArgoCD installed"

# Wait for ArgoCD to be ready
echo ""
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd \
  --timeout=300s

echo -e "${GREEN}✓${NC} ArgoCD is ready"

# Apply self-management Application
echo ""
echo "Applying ArgoCD self-management..."
kubectl apply -f "$(dirname "$0")/argocd-self-management.yaml"
echo -e "${GREEN}✓${NC} Self-management Application created"

# Apply ArgoCD config Application
echo ""
echo "Applying ArgoCD custom configurations..."
kubectl apply -f "$(dirname "$0")/argocd-config-application.yaml"
echo -e "${GREEN}✓${NC} Config Application created"

# Get admin password
echo ""
echo "======================================"
echo -e "${GREEN}ArgoCD Installation Complete!${NC}"
echo "======================================"
echo ""
echo "Admin Username: admin"
echo -n "Admin Password: "
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo -e "${YELLOW}To access ArgoCD UI:${NC}"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then visit: http://localhost:8080"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Login to ArgoCD UI"
echo "  2. Deploy your applications (Vault, External Secrets, etc.)"
echo "  3. Change the admin password!"
echo ""

