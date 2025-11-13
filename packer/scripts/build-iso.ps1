param(
  [string]$SourceISO = "C:\isos\Win11.iso",
  [string]$OutputISO = "C:\isos\Win11-Custom.iso",
  [string]$UnattendFile = "C:\workspace\windows-proxmox-automation\packer\autounattend.xml"
)

Write-Host "Building custom Windows 11 ISO..."

Mount-DiskImage -ImagePath $SourceISO
$mount = (Get-DiskImage $SourceISO | Get-Volume).DriveLetter + ":"

$workingDir = "C:\isos\Win11Custom"
New-Item -ItemType Directory -Force -Path $workingDir | Out-Null
Copy-Item "$mount\*" $workingDir -Recurse

Copy-Item $UnattendFile "$workingDir\autounattend.xml"

$boot1 = "$workingDir\boot\etfsboot.com"
$boot2 = "$workingDir\efi\microsoft\boot\efisys.bin"

oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$boot1"#pEF,e,b"$boot2" "$workingDir" "$OutputISO"

Dismount-DiskImage -ImagePath $SourceISO

Write-Host "Custom ISO created: $OutputISO"
