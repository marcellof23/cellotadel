# Cellotadel - Homelab Infrastructure as Code

This repository contains Terraform configurations for setting up a Kubernetes cluster using Talos Linux on Proxmox VE. The project automates the deployment of a homelab environment with a focus on reliability and security.

## Overview

Cellotadel automates the creation of a Kubernetes cluster with the following components:
- Proxmox VE as the virtualization platform
- Talos Linux as the operating system
- Single control plane node with high availability preparation
- Worker node for running workloads
- Automated configuration and bootstrap process

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

## Configuration

### Variables

Key variables that need to be configured:

```hcl
cluster_name         = "homelab-nas"
kubernetes_version   = "1.32.0"
default_gateway     = "192.168.0.1"
cp_vip             = "192.168.0.202"
```

### Network Configuration

The cluster is configured with the following IP addresses:
- Control Plane Node: 192.168.0.205
- Worker Node: 192.168.0.206
- Control Plane VIP: 192.168.0.202

## Virtual Machine Specifications

### Control Plane Node
- 2 CPU cores (x86-64-v2-AES)
- 4GB RAM
- 20GB disk
- Network bridge: vmbr0

### Worker Node
- 4 CPU cores (x86-64-v2-AES)
- 4GB RAM
- 20GB disk
- Network bridge: vmbr0

## Usage

1. Configure your Proxmox credentials in `proxmox.tfvars`:
```hcl
pve_api_url = "https://your-proxmox-server:8006/api2/json"
pve_user = "your-user@pam"
pve_password = "your-password"
node = "your-proxmox-node"
```

2. Initialize Terraform:
```bash
terraform init
```

3. Apply the configuration:
```bash
terraform apply -var-file="proxmox.tfvars"
```

4. After successful deployment, the kubeconfig and talosconfig will be automatically saved to:
- `~/.kube/config`
- `~/.talos/config`

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
