# This script downloads virtio drivers from a public URL (or you can stage them on a local webserver) # For reliability you might want to host the virtio ISO on an internal HTTP server; packer can attach it.
$virtioIsoUrl = 'https://fedorapeople.org/groups/virt/virtio-win/directdownloads/stable-virtio/virtio-win.iso' $dest = 'C:\Windows\Temp\virtio.iso'
Invoke-WebRequest -Uri $virtioIsoUrl -OutFile $dest
# Mount the ISO $drive = Mount-DiskImage -ImagePath $dest -PassThru | Get-Volume | SelectObject -First 1 $drvLetter = $drive.DriveLetter + ':'
# Install driver for net (example: use vnctest) pnputil /add-driver "$($drvLetter)\\viostor\\w10\\amd64\\*.inf" /install / subdirs pnputil /add-driver "$($drvLetter)\\NetKVM\\w10\\amd64\\*.inf" /install / subdirs
Dism /Online /Add-Driver /Driver:$($drvLetter)\\viostor\\w10\\amd64 /Recurse
# Dism may complain about unsigned drivers when Secure Boot enabled. Write-Host "VirtIO drivers installed (if Secure Boot blocks, ensure Secure Boot disabled on the VM or sign drivers)."
# Dismount Dismount-DiskImage -ImagePath $dest
