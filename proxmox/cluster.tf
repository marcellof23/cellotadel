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
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
      }
    }),
    templatefile("./templates/cpnetwork.yaml.tmpl", { cpip = var.cp_vip })
  ]
}

data "talos_machine_configuration" "machineconfig_worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.talos_cp_01_ip_addr}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.machine_secrets.machine_secrets
}

resource "talos_machine_configuration_apply" "worker_config_apply" {
  depends_on                  = [ proxmox_virtual_environment_vm.talos_worker_01 ]
  client_configuration        = talos_machine_secrets.machine_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.machineconfig_worker.machine_configuration
  count                       = 1
  node                        = var.talos_worker_01_ip_addr
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
      }
    }),
    templatefile("./templates/workernetwork.yaml.tmpl")
  ]
}

resource "null_resource" "wait_bootstrap" {
  depends_on = [proxmox_virtual_environment_vm.talos_cp_01]

  provisioner "local-exec" {
    command = <<EOT
      counter=0
      while [ $counter -lt 24 ] ; do
        if nc -z "${var.talos_cp_01_ip_addr}" 50000 ; then
          echo "Talos API is reachable on ${var.talos_cp_01_ip_addr}:50000..."
          sleep 30   # Delay to ensure Talos is fully up
          exit 0
        fi
        echo "Waiting for Talos API on ${var.talos_cp_01_ip_addr}:50000..."
        sleep 5
        counter=$(($counter + 1))
      done
      echo "Timeout reached. Talos API is not reachable."
      exit 1
    EOT
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
  timeouts             = { read = "90s" }
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
resource "null_resource" "run_custom_script" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.kube ~/.talos
      terraform output -raw kubeconfig > ~/.kube/config
      terraform output -raw talosconfig > ~/.talos/config
      chmod 600 ~/.kube/config ~/.talos/config
    EOT
  }

  triggers = {
    kubeconfig  = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
    talosconfig = data.talos_client_configuration.talosconfig.talos_config
    timestamp   = timestamp() # Ensure the resource always detects changes
  }

  depends_on = [
    talos_cluster_kubeconfig.kubeconfig,
    data.talos_client_configuration.talosconfig,
    data.talos_cluster_health.health
  ]
}
