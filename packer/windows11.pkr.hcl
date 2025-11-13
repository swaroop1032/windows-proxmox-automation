packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.1.5"
    }
  }
}

variable "proxmox_url" {
  default = "https://192.168.31.180:8006/api2/json"
}

variable "proxmox_username" {
  description = "Proxmox username. Either full token form user@realm!tokenid OR a short token id (then pipeline prepends terraform@pam!)"
  type        = string
}

variable "proxmox_token" {
  description = "Proxmox API token secret"
  type        = string
}

variable "winrm_username" {
  default = "Administrator"
}

variable "winrm_password" {
  description = "Windows Administrator password (passed from Jenkins credential WIN_ADMIN_PASSWORD)"
  type        = string
}

source "proxmox-iso" "win11" {
  proxmox_url = var.proxmox_url
  username    = var.proxmox_username
  token       = var.proxmox_token

  node    = "pve"
  pool    = ""          # optional resource pool name
  vm_name = "win11-template-build"
  vm_id   = 9001

  boot_iso {
  iso_url          = "https://software.download.prss.microsoft.com/dbazure/Win11_25H2_EnglishInternational_x64.iso"
  iso_checksum     = "sha256:D141F6030FED50F75E2B03E1EB2E53646C4B21E5386047CB860AF5223F102A32"
  iso_storage_pool = "local"    # must be an ISO-capable storage on your Proxmox (see note below)
  unmount          = true
}

  additional_iso_files {
    cd_files         = ["autounattend.xml"]
    cd_label         = "AUTOUNATTEND"
    iso_storage_pool = "local"    # where the generated ISO will be stored
  }

  memory  = 4096
  cores   = 4
  sockets = 1

  # Correct disk block keys for this plugin version:
  disks {
    disk_size    = "50G"
    storage_pool = "local-lvm"
    type         = "scsi"
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  qemu_agent = true

  template_name        = "win11-proxmox-template"
  template_description = "Windows 11 Pro template (built by packer)"

  communicator    = "winrm"
  winrm_username  = var.winrm_username
  winrm_password  = var.winrm_password
  winrm_timeout   = "2h"

  insecure_skip_tls_verify = true
  task_timeout             = "10m"
}

build {
  sources = ["source.proxmox-iso.win11"]

  provisioner "powershell" {
    script = "scripts/enable-winrm.ps1"
  }

  provisioner "powershell" {
    script = "scripts/install-virtio.ps1"
  }

  provisioner "powershell" {
    script = "scripts/optimize.ps1"
  }

  provisioner "powershell" {
    script = "scripts/sysprep.ps1"
  }
}




