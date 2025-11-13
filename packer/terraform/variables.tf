variable "pm_api_url" { type = string default = "https://192.168.31.180:8006/api2/json" }
variable "pm_api_token_id" { type = string }
variable "pm_api_token_secret" { type = string }
variable "vm_name" { type = string default = "win11-vm" }
variable "node" { type = string default = "pve" }
variable "storage" { type = string default = "local-lvm" }
