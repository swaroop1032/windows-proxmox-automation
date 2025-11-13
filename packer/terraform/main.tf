provider "proxmox" {
  pm_api_url = "https://${var.proxmox_host}:8006/api2/json"
  pm_user    = "root@pam"
  pm_password = var.proxmox_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "win11_clone" {
  name         = "win11-${var.vm_name}"
  target_node  = "pve"
  clone        = "win11-golden-template"
  full_clone   = true
  cores        = 4
  memory       = 8192

  disk {
    size    = "80G"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type = "win11"
  agent   = 1
  boot    = "cdn"
}

