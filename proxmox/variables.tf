
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