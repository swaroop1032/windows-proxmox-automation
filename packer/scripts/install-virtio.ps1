$iso = "C:\Windows\Temp\virtio.iso"
Invoke-WebRequest -Uri "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" -OutFile $iso

$disk = Mount-DiskImage -ImagePath $iso -PassThru
$vol  = ($disk | Get-Volume).DriveLetter + ":"

pnputil /add-driver "$vol\NetKVM\w10\amd64\*.inf" /install /subdirs
pnputil /add-driver "$vol\viostor\w10\amd64\*.inf" /install /subdirs

Dismount-DiskImage -ImagePath $iso
