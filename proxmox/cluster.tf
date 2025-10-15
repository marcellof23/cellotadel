resource "talos_machine_secrets" "machine_secrets" {
}

data "talos_client_configuration" "talosconfig" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  endpoints            = [var.talos_cp_01_ip_addr]
}

data "talos_machine_configuration" "machineconfig_cp" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
  kubernetes_version = var.kubernetes_version
}

resource "talos_machine_configuration_apply" "cp_config_apply" {
  depends_on                  = [ proxmox_virtual_environment_vm.talos_cp_01 ]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_cp.machine_configuration
  count                       = 1
  node                        = var.talos_cp_01_ip_addr
  config_patches = [
    templatefile("${path.module}/templates/cpnetwork.yaml.tmpl", { cpip = var.cp_vip })
  ]
}
# Worker Machine Configurations
data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

data "talos_machine_configuration" "machineconfig_worker_02" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

data "talos_machine_configuration" "machineconfig_worker_03" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

# Apply Worker Configurations
resource "talos_machine_configuration_apply" "worker_config_apply" {
  depends_on                  = [ proxmox_virtual_environment_vm.talos_worker_01 ]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
  count                       = 1
  node                        = var.talos_worker_01_ip_addr
  config_patches = [
    file("${path.module}/templates/workernetwork.yaml.tmpl")
  ]
}

resource "talos_machine_configuration_apply" "worker_config_apply_02" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_worker_02]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker_02.machine_configuration
  node                        = var.talos_worker_02_ip_addr
  config_patches = [
    file("${path.module}/templates/workernetwork.yaml.tmpl")
  ]
}

resource "talos_machine_configuration_apply" "worker_config_apply_03" {
  depends_on                  = [proxmox_virtual_environment_vm.talos_worker_03]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker_03.machine_configuration
  node                        = var.talos_worker_03_ip_addr
  config_patches = [
    file("${path.module}/templates/workernetwork.yaml.tmpl")
  ]
}

resource "null_resource" "wait_bootstrap" {
  depends_on = [proxmox_virtual_environment_vm.talos_cp_01]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = templatefile("${path.module}/templates/wait_bootstrap.sh.tmpl", {
      talos_ip = var.talos_cp_01_ip_addr
    })
  }

  triggers = {
    talos_node_ip = var.talos_cp_01_ip_addr
  }
}

resource "talos_machine_bootstrap" "bootstrap" {
  depends_on           = [ null_resource.wait_bootstrap ]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_cp_01_ip_addr
  timeouts             = { create = "60s" }
}

data "talos_cluster_health" "health" {
  depends_on           = [ null_resource.wait_bootstrap ]
  skip_kubernetes_checks = true
  client_configuration = data.talos_client_configuration.talosconfig.client_configuration
  control_plane_nodes  = [ var.talos_cp_01_ip_addr ]
  worker_nodes         = [ var.talos_worker_01_ip_addr ]
  endpoints            = data.talos_client_configuration.talosconfig.endpoints
  timeouts             = { read = "240s" }
}

resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [ talos_machine_bootstrap.bootstrap, data.talos_cluster_health.health ]
  client_configuration = talos_machine_secrets.machine_secrets.client_configuration
  node                 = var.talos_cp_01_ip_addr
}

output "talosconfig" {
  value = data.talos_client_configuration.talosconfig.talos_config
  sensitive = true
}

output "kubeconfig" {
  value = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

# Custom Script for Configuration
resource "null_resource" "output_config" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = file("${path.module}/templates/output_config.sh.tmpl")

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
