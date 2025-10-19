# Homelab Deployment Guide

Complete guide to deploying your homelab infrastructure using Terraform and ArgoCD.

## Prerequisites

- Proxmox VE installed and configured
- Terraform >= 1.5
- kubectl
- helm
- Git

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Terraform                         │
│  • Provisions Proxmox VMs                           │
│  • Deploys Talos Linux                              │
│  • Bootstraps Kubernetes cluster                    │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│            Manual ArgoCD Installation                │
│  • Install via bootstrap script or Helm             │
│  • Configure self-management                        │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│                    ArgoCD                            │
│  • Self-manages its own configuration               │
│  • Deploys all applications via GitOps              │
│  • Continuous sync from Git repository              │
└───────────────────┬─────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│              Your Applications                       │
│  • Vault (secret management)                        │
│  • External Secrets Operator                        │
│  • Longhorn (storage)                               │
│  • Immich (photo management)                        │
│  • MetalLB (load balancer)                          │
│  • Nginx Ingress                                    │
│  • Tailscale (networking)                           │
└─────────────────────────────────────────────────────┘
```

## Quick Start

### Step 1: Configure Your Infrastructure

1. **Edit Proxmox configuration**:
   ```bash
   cd proxmox/
   cp proxmox.tfvars.example proxmox.tfvars  # If example exists
   nano proxmox.tfvars
   ```

2. **Customize your cluster topology** in `proxmox.tfvars`:
   ```hcl
   # Add/remove nodes as needed
   control_plane_nodes = [
     {
       name      = "talos-cp-01"
       ip        = "192.168.0.205"
       cpu_cores = 4
       memory    = 4096
       disk_size = 40
     }
   ]
   
   worker_nodes = [
     {
       name      = "talos-worker-01"
       ip        = "192.168.0.206"
       cpu_cores = 4
       memory    = 4096
       disk_size = 180
     },
     # Add more workers here...
   ]
   ```

### Step 2: Deploy Infrastructure

```bash
cd proxmox/

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

This will:
1. ✅ Create Proxmox VMs (control plane + workers)
2. ✅ Install Talos Linux on all nodes
3. ✅ Bootstrap the Kubernetes cluster
4. ✅ Save kubeconfig and talosconfig files

### Step 3: Access Your Cluster

After Terraform completes:

```bash
# Kubeconfig is saved in proxmox/kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

### Step 4: Install ArgoCD

Run the bootstrap script to install ArgoCD:

```bash
cd ../argocd/
./bootstrap-argocd.sh
```

The script will automatically display the admin password when complete.

Alternatively, install manually:
```bash
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --version 7.7.0 \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true
```

### Step 5: Access ArgoCD

Get the admin password:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

Port forward to access the UI:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Visit http://localhost:8080 and login with:
- Username: `admin`
- Password: (from above command)

### Step 6: Deploy Applications via ArgoCD

Now deploy your applications using ArgoCD:

```bash
# Deploy Vault
kubectl apply -f argocd/apps/vault/vault-application.yaml

# Deploy External Secrets Operator
kubectl apply -f argocd/apps/vault/external-secrets-application.yaml

# Deploy Vault configuration
kubectl apply -f argocd/apps/vault/vault-config-application.yaml

# Deploy other applications
kubectl apply -f argocd/apps/immich/argocd-application.yaml
kubectl apply -f argocd/apps/longhorn/app.yaml
# ... etc
```

## Scaling Your Cluster

### Add Worker Nodes

1. Edit `proxmox/proxmox.tfvars`:
   ```hcl
   worker_nodes = [
     # ... existing workers ...
     {
       name      = "talos-worker-04"
       ip        = "192.168.0.210"
       cpu_cores = 8
       memory    = 8192
       disk_size = 200
     }
   ]
   ```

2. Apply changes:
   ```bash
   cd proxmox/
   terraform apply
   ```

### Add Control Plane Nodes (for HA)

1. Edit `proxmox/proxmox.tfvars`:
   ```hcl
   control_plane_nodes = [
     {
       name      = "talos-cp-01"
       ip        = "192.168.0.205"
       cpu_cores = 4
       memory    = 4096
       disk_size = 40
     },
     {
       name      = "talos-cp-02"
       ip        = "192.168.0.209"
       cpu_cores = 4
       memory    = 4096
       disk_size = 40
     }
   ]
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

## Application Management

### Deploy New Application

1. Create application manifests in `argocd/apps/<app-name>/`
2. Create ArgoCD Application manifest
3. Apply via kubectl or ArgoCD UI
4. ArgoCD automatically syncs from Git

### Update Existing Application

1. Edit files in `argocd/apps/<app-name>/`
2. Commit and push to Git
3. ArgoCD automatically syncs changes (if automated sync enabled)

## Disaster Recovery

### Backup Important Data

```bash
# Backup kubeconfig
cp proxmox/kubeconfig ~/.kube/homelab-backup

# Backup talosconfig
cp proxmox/talosconfig ~/.talos/homelab-backup

# Export all ArgoCD Applications
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Backup Vault data (if not in dev mode)
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/snapshot.snap
kubectl cp vault/vault-0:/tmp/snapshot.snap ./vault-snapshot.snap
```

### Restore Cluster

If you need to rebuild:

```bash
# Destroy and recreate with Terraform
cd proxmox/
terraform destroy
terraform apply

# Applications will be automatically restored via ArgoCD
```

## Troubleshooting

### Terraform Issues

```bash
# View Terraform state
terraform show

# Refresh state
terraform refresh

# Taint a resource to force recreation
terraform taint proxmox_virtual_environment_vm.worker[\"talos-worker-01\"]
```

### Cluster Issues

```bash
# Check Talos health
talosctl health --talosconfig proxmox/talosconfig

# Check node status
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A
```

### ArgoCD Issues

```bash
# Check ArgoCD health
kubectl get applications -n argocd

# Force application sync
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

## Directory Structure

```
.
├── DEPLOYMENT.md              # This file
├── README.md                  # Project overview
├── proxmox/                   # Infrastructure as Code
│   ├── cluster.tf            # Talos cluster configuration
│   ├── virtual_machines.tf   # VM definitions
│   ├── variables.tf          # Variable definitions
│   ├── proxmox.tfvars        # Your configuration
│   └── README.md             # Proxmox setup guide
└── argocd/                    # GitOps and applications
    ├── bootstrap-argocd.sh   # ArgoCD installation script
    ├── argocd-self-management.yaml  # Self-management config
    ├── argocd-config-application.yaml
    ├── config/               # Custom ArgoCD configurations
    └── apps/                 # All application manifests
        ├── vault/            # Vault + External Secrets
        ├── immich/           # Immich photo app
        ├── longhorn/         # Storage provider
        ├── metallb/          # Load balancer
        ├── nginx/            # Ingress controller
        └── tailscale/        # VPN networking
```

## Next Steps

1. **Configure Vault secrets** - Update `argocd/apps/vault/config/vault-secrets-job.yaml`
2. **Set up ingress** - Configure your domain and TLS certificates
3. **Enable monitoring** - Add Prometheus + Grafana
4. **Configure backups** - Set up Longhorn backup targets
5. **Harden security** - Enable RBAC, network policies, etc.

## Support

- Terraform docs: https://www.terraform.io/docs
- Talos docs: https://www.talos.dev/docs
- ArgoCD docs: https://argo-cd.readthedocs.io
- Proxmox docs: https://pve.proxmox.com/wiki/Main_Page

