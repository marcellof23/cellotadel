locals {
  # Extract IPs for easier reference
  control_plane_ips = [for node in var.control_plane_nodes : node.ip]
  worker_ips        = [for node in var.worker_nodes : node.ip]
  first_cp_ip       = var.control_plane_nodes[0].ip
}

resource "talos_machine_secrets" "machine_secrets" {
}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = [local.first_cp_ip]
}

# Control Plane Machine Configuration
data "talos_machine_configuration" "machineconfig_cp" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${local.first_cp_ip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.machine_secrets.machine_secrets
  kubernetes_version = var.kubernetes_version
}

# Apply Control Plane Configurations
resource "talos_machine_configuration_apply" "cp_config_apply" {
  for_each = { for node in var.control_plane_nodes : node.name => node }

  depends_on                  = [proxmox_virtual_environment_vm.control_plane]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_cp.machine_configuration
  node                        = each.value.ip
  config_patches = [
    templatefile("${path.module}/templates/cpnetwork.yaml.tmpl", { cpip = var.cp_vip })
  ]
}

# Worker Machine Configuration
data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.first_cp_ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

# Apply Worker Configurations
resource "talos_machine_configuration_apply" "worker_config_apply" {
  for_each = { for node in var.worker_nodes : node.name => node }

  depends_on                  = [proxmox_virtual_environment_vm.worker]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
  node                        = each.value.ip
  config_patches = [
    file("${path.module}/templates/workernetwork.yaml.tmpl")
  ]
}

resource "null_resource" "wait_bootstrap" {
  depends_on = [proxmox_virtual_environment_vm.control_plane]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = templatefile("${path.module}/templates/wait_bootstrap.sh.tmpl", {
      talos_ip = local.first_cp_ip
    })
  }

  triggers = {
    talos_node_ip = local.first_cp_ip
  }
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [null_resource.wait_bootstrap]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.first_cp_ip
  timeouts             = { create = "60s" }
}

data "talos_cluster_health" "health" {
  depends_on             = [null_resource.wait_bootstrap]
  skip_kubernetes_checks = true
  client_configuration   = data.talos_client_configuration.talosconfig.client_configuration
  control_plane_nodes    = local.control_plane_ips
  worker_nodes           = local.worker_ips
  endpoints              = data.talos_client_configuration.talosconfig.endpoints
  timeouts               = { read = "240s" }
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.bootstrap, data.talos_cluster_health.health]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = local.first_cp_ip
}

output "talosconfig" {
  value     = data.talos_client_configuration.talosconfig.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

# Custom Script for Configuration
resource "null_resource" "output_config" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = file("${path.module}/templates/output_config.sh.tmpl")

    environment = {
      TF_VAR_KUBECONFIG_DATA  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
      TF_VAR_TALOSCONFIG_DATA = data.talos_client_configuration.talosconfig.talos_config
    }
  }

  triggers = {
    kubeconfig_sha  = sha256(talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw)
    talosconfig_sha = sha256(data.talos_client_configuration.talosconfig.talos_config)
  }

  depends_on = [
    talos_cluster_kubeconfig.kubeconfig,
    data.talos_client_configuration.talosconfig,
    data.talos_cluster_health.health
  ]
}
