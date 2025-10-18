# Control Plane VMs
resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each = { for node in var.control_plane_nodes : node.name => node }

  name        = each.value.name
  description = "Managed by Terraform"
  tags        = ["terraform", "control-plane"]
  node_name   = var.node
  on_boot     = false

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = false
  }

  stop_on_destroy = true

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
    file_format  = "raw"
    interface    = "virtio0"
    size         = each.value.disk_size
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "local-zfs"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}

# Worker VMs
resource "proxmox_virtual_environment_vm" "worker" {
  for_each = { for node in var.worker_nodes : node.name => node }

  # Ensure all control plane nodes are created before workers
  depends_on = [proxmox_virtual_environment_vm.control_plane]

  name        = each.value.name
  description = "Managed by Terraform"
  tags        = ["terraform", "worker"]
  node_name   = var.node
  on_boot     = false

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = false
  }

  stop_on_destroy = true

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
    file_format  = "raw"
    interface    = "virtio0"
    size         = each.value.disk_size
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 5.X.
  }

  initialization {
    datastore_id = "local-zfs"
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.default_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}
