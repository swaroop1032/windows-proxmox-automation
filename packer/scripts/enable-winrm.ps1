param([string]$AdminPassword)


# Enable WinRM
winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'


# Allow Basic (temporarily) and enable unencrypted for build (Packer runs in a lab)
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'


# Set network profile to private/work to allow WinRM through firewall
$ns = Get-NetConnectionPro
