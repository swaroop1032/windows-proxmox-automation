pipeline {
  agent any

  environment {
    TF_IN_AUTOMATION = "1"
    PROXMOX_HOST = "192.168.31.180"
    PROXMOX_API_BASE = "https://192.168.31.180:8006/api2/json"
    PROXMOX_NODE = "pve"
    ISO_STORAGE = "local"
    ISO_FILENAME = "Win11_25H2_EnglishInternational_x64.iso"
    ISO_FILE_REF = "${ISO_STORAGE}:iso/${ISO_FILENAME}"
    COMMON_ISO_PATHS = "C:\\Users\\Public\\Downloads;C:\\Users\\%USERNAME%\\Downloads;C:\\jenkins_cache;D:\\isos"
    ISO_SOURCE_URL = "https://software.download.prss.microsoft.com/dbazure/Win11_25H2_EnglishInternational_x64.iso"
    UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Ensure ISO on Proxmox') {
  steps {
    dir('packer') {
      withCredentials([
        string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PM_ID'),
        string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PM_SECRET')
      ]) {
        // read the script relative to the current dir('packer')
        powershell script: readFile('scripts/ensure_iso.ps1'), returnStatus: false
      }
    }
  }
}


    stage('Prepare Packer (use uploaded ISO)') {
      steps {
        dir('packer') {
          powershell '''
$hclFile = "windows11.pkr.hcl"
$backup = "$hclFile.bak"
Copy-Item -Path $hclFile -Destination $backup -Force

$isoVolidFile = "..\\iso_volid.txt"
if (-Not (Test-Path $isoVolidFile)) {
  Write-Error "iso_volid.txt not found. Ensure Ensure-ISO stage succeeded."
  exit 1
}
$isoVolid = Get-Content $isoVolidFile -Raw

# Read all lines
[string[]]$lines = Get-Content -Path $hclFile -ErrorAction Stop

$startIndex = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].TrimStart().StartsWith("boot_iso")) {
        $startIndex = $i
        break
    }
}

if ($startIndex -eq -1) {
    $replacementBlock = @(
        "boot_iso {",
        "  iso_file = ""$isoVolid""",
        "  unmount  = true",
        "}"
    )
    $newContent = $lines + $replacementBlock
    $newContent | Set-Content -Path $hclFile -Encoding UTF8
    Write-Host ("No existing boot_iso found. Appended iso block.")
    exit 0
}

$braceCount = 0
$endIndex = -1
for ($j = $startIndex; $j -lt $lines.Length; $j++) {
    $line = $lines[$j]
    $open = ($line -split '{').Length - 1
    $close = ($line -split '}').Length - 1
    $braceCount += $open
    $braceCount -= $close
    if ($braceCount -eq 0 -and $j -gt $startIndex) {
        $endIndex = $j
        break
    }
}

if ($endIndex -eq -1) {
    Write-Error "Could not find end of boot_iso block. Aborting to avoid corrupting file."
    exit 1
}

$before = if ($startIndex -gt 0) { $lines[0..($startIndex - 1)] } else { @() }
$after = if ($endIndex -lt $lines.Length - 1) { $lines[($endIndex + 1)..($lines.Length - 1)] } else { @() }

$replacementBlock = @(
    "boot_iso {",
    "  iso_file = ""$isoVolid""",
    "  unmount  = true",
    "}"
)

$newLines = $before + $replacementBlock + $after
$newLines | Set-Content -Path $hclFile -Encoding UTF8

Write-Host ("Replaced boot_iso block with iso_file: {0}" -f $isoVolid)
'''
        }
      }
    }

    stage('Packer Build') {
      steps {
        dir('packer') {
          withCredentials([
            string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PM_SECRET'),
            string(credentialsId: 'WIN_ADMIN_PASSWORD', variable: 'WINPASS')
          ]) {
            powershell '''
Write-Host "Starting packer init & build..."

if ($env:PM_ID -match '!') {
  $proxmox_username = $env:PM_ID
} else {
  $proxmox_username = "terraform@pam!$($env:PM_ID)"
}

packer init .
if ($LASTEXITCODE -ne 0) { Write-Error "packer init failed"; exit $LASTEXITCODE }

packer build -var "proxmox_username=$proxmox_username" -var "proxmox_token=$env:PM_SECRET" -var "winrm_password=$env:WINPASS" windows11.pkr.hcl
if ($LASTEXITCODE -ne 0) { Write-Error "packer build failed"; exit $LASTEXITCODE }

Write-Host "Packer build completed."
'''
          }
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        dir('terraform') {
          withCredentials([
            string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PM_SECRET')
          ]) {
            powershell '''
if ($env:PM_ID -match '!') {
  $tf_token_id = $env:PM_ID
} else {
  $tf_token_id = "terraform@pam!$($env:PM_ID)"
}

terraform init -input=false
if ($LASTEXITCODE -ne 0) { Write-Error "terraform init failed"; exit $LASTEXITCODE }

terraform apply -auto-approve -var "pm_api_token_id=$tf_token_id" -var "pm_api_token_secret=$env:PM_SECRET"
if ($LASTEXITCODE -ne 0) { Write-Error "terraform apply failed"; exit $LASTEXITCODE }

Write-Host "Terraform apply done."
'''
          }
        }
      }
    }

  } // end stages

  post {
    always {
      echo "Pipeline finished — check logs above for details."
    }
    failure {
      echo "Pipeline failed. See console output for errors."
    }
    success {
      echo "Pipeline succeeded — template created and VM provisioned."
    }
  }
}

