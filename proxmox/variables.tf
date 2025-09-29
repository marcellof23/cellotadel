
variable "cluster_name" {
  type    = string
  default = "homelab-nas"
}

variable "default_gateway" {
  type    = string
  default = "192.168.0.1"
}

variable "talos_cp_01_ip_addr" {
  type    = string
  default = "192.168.0.205"
}

variable "talos_worker_01_ip_addr" {
  type    = string
  default = "192.168.0.206"
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
  description = "Proxmox passsword"
  type        = string
  sensitive   = true
}
