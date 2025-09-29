provider "proxmox" {
  endpoint = var.pve_api_url
  username = var.pve_user
  password = var.pve_password
}
