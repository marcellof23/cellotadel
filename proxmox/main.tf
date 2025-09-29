provider "proxmox" {
  endpoint = var.pve_api_url
  username = var.pve_user
  password = var.pve_password
  #insecure = true # Only needed if your Proxmox server is using a self-signed certificate
}
