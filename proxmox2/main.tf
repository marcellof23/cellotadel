terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "~> 0.75.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = "~> 0.7.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.0.202:8006/"
  insecure = true
}

# Download Talos image
resource "proxmox_virtual_environment_download_file" "talos_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.9.5/metal-amd64.qcow2"
  file_name    = "talos-1.9.5-amd64.img"
}

# Control plane VM
resource "proxmox_virtual_environment_vm" "control_plane" {
  name        = "talos-cp-01"
  description = "Talos control plane node"
  node_name   = "pve"
  
  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    interface    = "virtio0"
    size         = 32
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }
}

# Worker VM
resource "proxmox_virtual_environment_vm" "worker" {
  name        = "talos-worker-01"
  description = "Talos worker node"
  node_name   = "pve"
  
  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    interface    = "virtio0"
    size         = 100
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }
}

# Talos configuration
resource "talos_machine_secrets" "secrets" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = "nas-cluster"
  machine_type     = "controlplane"
  cluster_endpoint = "https://192.168.0.210:6443"
  machine_secrets  = talos_machine_secrets.secrets.machine_secrets
}

data "talos_machine_configuration" "worker" {
  cluster_name     = "nas-cluster"
  machine_type     = "worker"
  cluster_endpoint = "https://192.168.0.210:6443"
  machine_secrets  = talos_machine_secrets.secrets.machine_secrets
}

# Apply configurations
resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                       = "192.168.0.210"
  config_patches = [
    <<EOT
machine:
  install:
    disk: "/dev/vda"
  network:
    interfaces:
      - interface: eth0
        addresses:
          - 192.168.0.210/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.0.1
    nameservers:
      - 192.168.0.1
EOT
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  client_configuration        = talos_machine_secrets.secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                       = "192.168.0.211"
  config_patches = [
    <<EOT
machine:
  install:
    disk: "/dev/vda"
  network:
    interfaces:
      - interface: eth0
        addresses:
          - 192.168.0.211/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.0.1
    nameservers:
      - 192.168.0.1
EOT
  ]
}

# Bootstrap the cluster
resource "talos_machine_bootstrap" "bootstrap" {
  node                 = "192.168.0.210"
  client_configuration = talos_machine_secrets.secrets.client_configuration
}

# Get kubeconfig
data "talos_cluster_kubeconfig" "kubeconfig" {
  client_configuration = talos_machine_secrets.secrets.client_configuration
  node                = "192.168.0.210"
  depends_on          = [talos_machine_bootstrap.bootstrap]
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}