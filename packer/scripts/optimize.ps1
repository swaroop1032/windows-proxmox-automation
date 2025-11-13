# small optimizations Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name ClearPageFileAtShutdown -Value 1 -Type DWord
# Disable hibernate powercfg -h off
# Windows update & reboot could be added here if desired Write-Host "Optimizations complete"
