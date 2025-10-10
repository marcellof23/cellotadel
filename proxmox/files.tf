
locals {
  talos = {
    version = "v1.11.1"
  }
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = var.node

  file_name               = "nocloud-amd64-${local.talos.version}.iso"
  url                     = "https://factory.talos.dev/image/64a1dc48ec306a9a656ef1eea0238afa76b5528ca851243969fe6c185e6ad223/${local.talos.version}/nocloud-amd64.iso"
  overwrite               = false
  overwrite_unmanaged     = true
}
