
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

variable "talos_cp_01_ip_addr" {
  type    = string
  default = "192.168.0.205"
}

variable "talos_worker_01_ip_addr" {
  type    = string
  default = "192.168.0.206"
}

variable "talos_worker_02_ip_addr" {
  type    = string
  default = "192.168.0.207"
}

variable "talos_worker_03_ip_addr" {
  type    = string
  default = "192.168.0.208"
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