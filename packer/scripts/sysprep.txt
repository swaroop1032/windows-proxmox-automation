Write-Host "Running Sysprep..."
Start-Process -FilePath "C:\Windows\System32\Sysprep\sysprep.exe" -ArgumentList "/oobe /generalize /shutdown" -Wait
