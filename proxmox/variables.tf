
variable "cluster_name" {
  type    = string
  default = "homelab-nas"
}

variable "default_gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "cp_vip" {
  type    = string
  default = "192.168.0.202"
}

variable "control_plane_nodes" {
  description = "List of control plane node configurations"
  type = list(object({
    name      = string
    ip        = string
    cpu_cores = number
    memory    = number
    disk_size = number
  }))
  default = [
    {
      name      = "talos-cp-01"
      ip        = "192.168.0.205"
      cpu_cores = 4
      memory    = 4096
      disk_size = 40
    }
  ]
}

variable "worker_nodes" {
  description = "List of worker node configurations"
  type = list(object({
    name      = string
    ip        = string
    cpu_cores = number
    memory    = number
    disk_size = number
  }))
  default = [
    {
      name      = "talos-worker-01"
      ip        = "192.168.0.206"
      cpu_cores = 4
      memory    = 4096
      disk_size = 180
    },
    {
      name      = "talos-worker-02"
      ip        = "192.168.0.207"
      cpu_cores = 4
      memory    = 4096
      disk_size = 180
    },
  ]
}

variable "node" {
  description = "Proxmox node"
  type        = string
}

variable "pve_api_url" {
  description = "Proxmox API Endpoint, e.g. 'https://pve.example.com/api2/json'"
  type        = string
  sensitive   = true
}

variable "pve_user" {
  description = "Proxmox username"
  type        = string
  sensitive   = true
}

variable "pve_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.32.0"
}