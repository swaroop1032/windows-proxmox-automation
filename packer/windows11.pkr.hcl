packer {
  required_plugins {
    proxmox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url"       { type = string }
variable "pm_token_id"       { type = string }
variable "pm_token_secret"   { type = string }
variable "win_admin_pass"    { type = string }

source "proxmox-iso" "win11" {
  proxmox_url          = var.proxmox_url
  proxmox_username     = "terraform@pam"
  proxmox_token_name   = var.pm_token_id
  proxmox_token_secret = var.pm_token_secret

  node          = "pve"
  storage_pool  = "local-lvm"
  vm_name       = "win11-template-build"
  vm_id         = 9001

  iso_url           = "https://software.download.prss.microsoft.com/dbazure/Win11_23H2_English_x64.iso"
  iso_checksum_type = "none"

  disk_size      = "50G"
  disk_interface = "scsi"
  memory         = 4096
  cores          = 4

  qemu_agent = true

  boot_wait  = "10s"

  communicator    = "winrm"
  winrm_username  = "Administrator"
  winrm_password  = var.win_admin_pass
  winrm_timeout   = "2h"

  unattended_file = "autounattend.xml"

  template_name  = "win11-proxmox-template"
  shutdown_timeout = "15m"
}

build {
  sources = ["source.proxmox-iso.win11"]

  provisioner "powershell" {
    script = "scripts/01-enable-winrm.ps1"
  }

  provisioner "powershell" {
    script = "scripts/02-install-virtio.ps1"
  }

  provisioner "powershell" {
    script = "scripts/03-optimize.ps1"
  }

  provisioner "powershell" {
    script = "scripts/04-sysprep.ps1"
  }
}
