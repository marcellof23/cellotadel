
locals {
  talos = {
    version = "v1.11.2"
  }
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = var.node

  file_name               = "nocloud-amd64-${local.talos.version}.iso"
  url                     = "https://factory.talos.dev/image/7fa1b6c2dc7d171c742b550c259128345a8173dbb8ca274f0ae785818e115e6a/${local.talos.version}/nocloud-amd64.iso"
  overwrite               = false
  overwrite_unmanaged     = true
}
