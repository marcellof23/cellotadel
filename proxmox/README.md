# Proxmox Talos Cluster Terraform Configuration

This Terraform configuration dynamically provisions Talos Linux VMs on Proxmox for a Kubernetes cluster.

## Architecture

The configuration creates:
- **Control Plane Nodes**: Dynamically scalable control plane VMs
- **Worker Nodes**: Dynamically scalable worker VMs
- **Talos Configuration**: Automated Talos machine configuration and bootstrap

## Quick Start

### 1. Configure Your Nodes

Edit `proxmox.tfvars` to define your desired cluster topology:

```hcl
control_plane_nodes = [
  {
    name      = "talos-cp-01"
    ip        = "192.168.0.205"
    cpu_cores = 2
    memory    = 4096
    disk_size = 35
  }
]

worker_nodes = [
  {
    name      = "talos-worker-01"
    ip        = "192.168.0.206"
    cpu_cores = 4
    memory    = 4096
    disk_size = 120
  },
  # Add more workers as needed...
]
```

### 2. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

## Scaling Your Cluster

### Add a Control Plane Node

Simply add another object to the `control_plane_nodes` list in `proxmox.tfvars`:

```hcl
control_plane_nodes = [
  {
    name      = "talos-cp-01"
    ip        = "192.168.0.205"
    cpu_cores = 2
    memory    = 4096
    disk_size = 35
  },
  {
    name      = "talos-cp-02"
    ip        = "192.168.0.209"
    cpu_cores = 2
    memory    = 4096
    disk_size = 35
  }
]
```

### Add a Worker Node

Add another object to the `worker_nodes` list:

```hcl
worker_nodes = [
  # ... existing workers ...
  {
    name      = "talos-worker-04"
    ip        = "192.168.0.210"
    cpu_cores = 8
    memory    = 8192
    disk_size = 100
  }
]
```

### Remove a Node

Simply delete the node object from the respective list and run `terraform apply`.

## Node Configuration Options

Each node supports the following configuration:

- `name`: VM name (must be unique)
- `ip`: Static IP address for the node
- `cpu_cores`: Number of CPU cores
- `memory`: RAM in MB (e.g., 4096 = 4GB)
- `disk_size`: Disk size in GB

## Important Notes

- All nodes are created on the Proxmox node specified in the `node` variable
- Control plane nodes are created before worker nodes
- The first control plane node is used as the bootstrap node
- Make sure IP addresses don't conflict with your network
- Disk sizes can vary per node to match your storage requirements

