packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/packer-plugin-proxmox"
      version = ">= 1.1.5"
    }
  }
}

variable "proxmox_url" {
  default = "https://192.168.31.180:8006/api2/json"
}

variable "proxmox_username" {
  # When using a token, set username like: "terraform@pam!tokenid"
  type = string
}

variable "proxmox_token" {
  type = string
}

variable "winrm_username" {
  default = "Administrator"
}

variable "winrm_password" {
  type = string
}

source "proxmox-iso" "win11" {
  proxmox_url = var.proxmox_url
  username    = var.proxmox_username
  token       = var.proxmox_token

  node    = "pve"
  pool    = ""          # optional resource pool name
  vm_name = "win11-template-build"
  vm_id   = 9001

  # Boot ISO — use iso_url to download from Microsoft (packer will try to download and cache)
  boot_iso {
    type        = "scsi"
    iso_url     = "https://software.download.prss.microsoft.com/dbazure/Win11_23H2_English_x64.iso"
    iso_checksum = ""   # optional, or "sha256:<checksum>"
    unmount     = true
  }

  # Attach additional ISO (autounattend) as a small CD so Windows picks it up,
  # or use additional_iso_files which creates a CD from local file(s)
  additional_iso_files {
    cd_files        = ["autounattend.xml"]
    cd_label        = "AUTOUNATTEND"
    iso_storage_pool = "local"   # storage where the generated CD ISO will be placed
  }

  # VM hardware
  memory = 4096
  cores  = 4
  sockets = 1

  # Disks: note array of disk configs
  disks {
    # Example disk — this will be used as the main disk
    type    = "scsi"
    storage = "local-lvm"
    size    = "50G"
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # QEMU guest agent is recommended
  qemu_agent = true

  # Template metadata
  template_name        = "win11-proxmox-template"
  template_description = "Windows 11 Pro template (built by packer)"

  # Communicator used for provisioning
  communicator = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "2h"

  insecure_skip_tls_verify = true   # set false if you have a valid cert
  task_timeout = "10m"
}

build {
  sources = ["source.proxmox-iso.win11"]

  provisioner "powershell" {
    # The autounattend.xml should already call a script to enable WinRM.
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
