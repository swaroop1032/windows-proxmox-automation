winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC"
