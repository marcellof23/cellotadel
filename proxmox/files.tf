
locals {
  talos = {
    version = "v1.11.1"
  }
}

resource "proxmox_virtual_environment_download_file" "talos_metal_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = "pve"

  file_name               = "metal-amd64.img"
  url                     = "https://factory.talos.dev/image/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/${local.talos.version}/metal-amd64.raw.zst"
  decompression_algorithm = "zst"
  overwrite               = false
}