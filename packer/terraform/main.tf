provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "win" {
  name        = var.vm_name
  target_node = var.node

  clone = "win11-proxmox-template"

  cores  = 4
  sockets = 1
  memory = 4096

  disk {
    slot    = 0
    size    = "50G"
    type    = "scsi"
    storage = var.storage
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}
