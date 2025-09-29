
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
  url                     = "https://factory.talos.dev/image/88d1f7a5c4f1d3aba7df787c448c1d3d008ed29cfb34af53fa0df4336a56040b/${local.talos.version}/nocloud-amd64.iso"
  overwrite               = false
  overwrite_unmanaged     = true
}
