# Cellotadel - Homelab Infrastructure as Code

This repository contains Terraform configurations for setting up a Kubernetes cluster using Talos Linux on Proxmox VE, with GitOps-based application deployment via ArgoCD. The project automates the deployment of a homelab environment with a focus on reliability and security.

## Overview

Cellotadel automates the creation of a Kubernetes cluster with the following components:
- **Infrastructure**: Proxmox VE virtualization platform
- **Operating System**: Talos Linux (immutable, secure Kubernetes OS)
- **Cluster**: Dynamically scalable control plane and worker nodes
- **GitOps**: ArgoCD for declarative application deployment
- **Secrets**: Vault + External Secrets Operator for secret management
- **Automated**: Terraform for infrastructure, ArgoCD for applications

## Prerequisites

- Proxmox VE server
- Terraform >= 1.0
- Network with DHCP for IPv6 (optional)
- Access to Proxmox API

## Required Providers

- `bpg/proxmox` (v0.83.1)
- `siderolabs/talos` (v0.9.0)
- `hashicorp/null` (v3.2.4)
- `hashicorp/local` (v2.4.0)

## Quick Start

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete deployment guide.

```bash
# 1. Deploy infrastructure
cd proxmox/
terraform apply

# 2. Install ArgoCD
cd ../argocd/
./bootstrap-argocd.sh

# 3. Deploy applications
kubectl apply -f apps/vault/vault-application.yaml
kubectl apply -f apps/immich/argocd-application.yaml
```

## Project Structure

```
cellotadel/
├── DEPLOYMENT.md              # Complete deployment walkthrough
├── proxmox/                   # Infrastructure as Code
│   ├── cluster.tf            # Talos cluster configuration
│   ├── virtual_machines.tf   # Dynamic VM provisioning
│   ├── variables.tf          # Variable definitions
│   └── proxmox.tfvars        # Your cluster configuration
└── argocd/                    # GitOps and applications
    ├── bootstrap-argocd.sh   # ArgoCD installation script
    ├── argocd-self-management.yaml
    ├── argocd-config-application.yaml
    └── apps/                  # All application manifests
        ├── vault/            # Vault + External Secrets
        ├── immich/           # Photo management
        ├── longhorn/         # Storage provider
        ├── metallb/          # Load balancer
        ├── nginx/            # Ingress controller
        └── tailscale/        # VPN networking
```

## Scaling

The infrastructure is fully dynamic - add/remove nodes by editing lists in `proxmox/proxmox.tfvars`:

```hcl
worker_nodes = [
  { name = "talos-worker-01", ip = "192.168.0.206", cpu_cores = 4, memory = 4096, disk_size = 180 },
  { name = "talos-worker-02", ip = "192.168.0.207", cpu_cores = 4, memory = 4096, disk_size = 180 },
  # Add more workers here...
]
```

## Features

- Automated VM provisioning on Proxmox
- Talos Linux configuration and bootstrap
- Kubernetes cluster setup
- Health checks and monitoring
- Automatic configuration file management
- IPv6 support (DHCP)

## Security Features

- Sensitive information marked as sensitive in Terraform
- Secure file permissions (600) for kubeconfig and talosconfig
- No QEMU guest agent for enhanced security
- Terraform-managed tags for resource tracking

## Outputs

- `talosconfig`: Talos configuration for cluster management
- `kubeconfig`: Kubernetes configuration for cluster access

## Notes

- The cluster is configured with a single control plane node but is prepared for high availability
- Worker nodes can be scaled by modifying the configuration
- All VMs are configured to not start automatically on boot (on_boot = false)
- The deployment includes waiting periods to ensure proper initialization

## License

This project is licensed under the MIT License - see the LICENSE file for details.
