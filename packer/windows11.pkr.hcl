packer_required_plugins {
iso_checksum_type = "sha256"
iso_checksum = ""


disk_size = "50G"
disk_interface = "scsi"
boot_wait = "10s"
memory = 4096
cores = 4


qemu_agent = true
enable_serial = false


communicator = "winrm"
winrm_username = "Administrator"
winrm_password = var.win_admin_pass
winrm_timeout = "2h"


unattended_file = "autounattend.xml"
shutdown_timeout = "30m"
template_name = "win11-proxmox-template"
}


build {
sources = ["source.proxmox-iso.win11"]


provisioner "powershell" {
inline = [
"Write-Host 'Running enable WinRM'",
"& './scripts/01-enable-winrm.ps1' -AdminPassword '\\"${var.win_admin_pass}\\"'"
]
}


provisioner "powershell" {
inline = [
"Write-Host 'Installing VirtIO drivers'",
"& './scripts/02-install-virtio.ps1'"
]
}


provisioner "powershell" {
inline = [
"Write-Host 'Windows optimization'",
"& './scripts/03-optimize.ps1'"
]
}


provisioner "powershell" {
inline = [
"Write-Host 'Sysprep'",
"& './scripts/04-sysprep.ps1'"
]
}
}
