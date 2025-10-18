# ArgoCD Bootstrap
# This installs ArgoCD initially via Terraform
# After installation, ArgoCD manages its own configuration via the self-management Application

resource "null_resource" "wait_for_cluster" {
  depends_on = [
    talos_cluster_kubeconfig.kubeconfig,
    data.talos_cluster_health.health
  ]

  provisioner "local-exec" {
    command = "sleep 30"
  }
}

# Create ArgoCD namespace
resource "null_resource" "create_argocd_namespace" {
  depends_on = [null_resource.wait_for_cluster]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    EOT
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }

  triggers = {
    cluster_id = data.talos_cluster_health.health.id
  }
}

# Install ArgoCD using Helm
resource "null_resource" "install_argocd" {
  depends_on = [null_resource.create_argocd_namespace]

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add argo https://argoproj.github.io/argo-helm
      helm repo update
      
      helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --version 7.7.0 \
        --set server.service.type=ClusterIP \
        --set configs.params."server\.insecure"=true \
        --wait \
        --timeout 10m
    EOT
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }

  triggers = {
    cluster_id = data.talos_cluster_health.health.id
    version    = "7.7.0"
  }
}

# Wait for ArgoCD to be ready
resource "null_resource" "wait_for_argocd" {
  depends_on = [null_resource.install_argocd]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ArgoCD to be ready..."
      kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=argocd-server \
        -n argocd \
        --timeout=300s
    EOT
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }
}

# Apply the self-management Application
# This allows ArgoCD to manage its own configuration from Git
resource "null_resource" "argocd_self_management" {
  depends_on = [null_resource.wait_for_argocd]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f ${path.module}/../apps/argocd/argocd-self-management.yaml
    EOT
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }

  triggers = {
    always_run = timestamp()
  }
}

# Output ArgoCD admin password
resource "null_resource" "get_argocd_password" {
  depends_on = [null_resource.wait_for_argocd]

  provisioner "local-exec" {
    command = <<-EOT
      echo ""
      echo "======================================"
      echo "ArgoCD Installation Complete!"
      echo "======================================"
      echo ""
      echo "ArgoCD Admin Password:"
      kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
      echo ""
      echo ""
      echo "Access ArgoCD:"
      echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
      echo "  Then visit: http://localhost:8080"
      echo "  Username: admin"
      echo ""
    EOT
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
  }
}

