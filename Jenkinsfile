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
    ISO_SOURCE_URL = "https://software.download.prss.microsoft.com/dbazure/Win11_23H2_English_x64.iso"
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
            string(credentialsId: 'PROXMOX_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_TOKEN_SECRET', variable: 'PM_SECRET'),
            string(credentialsId: 'ISO_LOCAL_PATH', variable: 'ISO_LOCAL_PATH_CRED')
          ]) {
            powershell '''
$apiBase = "${env.PROXMOX_API_BASE}"
$node = "${env.PROXMOX_NODE}"
$isoStorage = "${env.ISO_STORAGE}"
$isoFileName = "${env.ISO_FILENAME}"
$isoRef = "${env.ISO_FILE_REF}"
$isoSourceUrl = "${env.ISO_SOURCE_URL}"
$userAgent = "${env.UA}"

if ($env:PM_ID -match '!') {
  $tokenId = $env:PM_ID
} else {
  $tokenId = "terraform@pam!$($env:PM_ID)"
}
$authHeader = "PVEAPIToken=$tokenId=$($env:PM_SECRET)"
$headers = @{ "Authorization" = $authHeader }

Write-Host "Checking Proxmox for ISO ($isoRef)..."
$listUri = "$apiBase/nodes/$node/storage/$isoStorage/content?content=iso"

try {
  $resp = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
  $items = $resp.data
  $exists = $items | Where-Object { $_.volid -eq $isoRef -or $_.volid -like "*$isoFileName" }
} catch {
  Write-Warning "Could not list Proxmox storage content: $_. Will continue to attempt upload."
  $exists = $null
}

if ($exists) {
  Write-Host "ISO already present on Proxmox: $($exists[0].volid). Skipping upload."
  exit 0
}

$localIsoCandidates = @()
if ($env:ISO_LOCAL_PATH_CRED -and (Test-Path $env:ISO_LOCAL_PATH_CRED)) {
  $localIsoCandidates += $env:ISO_LOCAL_PATH_CRED
}

$commonList = "${env.COMMON_ISO_PATHS}".Split(';')
foreach ($p in $commonList) {
  $p2 = $p -replace '%USERNAME%', $env:USERNAME
  $candidate = Join-Path $p2 $isoFileName
  $localIsoCandidates += $candidate
}

$localIso = $localIsoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($localIso) {
  Write-Host "Found local ISO on Jenkins agent: $localIso"
} else {
  Write-Host "No local ISO found. Attempting to download from Microsoft..."
  $downloadDir = "C:\\jenkins_cache"
  if (-not (Test-Path $downloadDir)) { New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null }
  $localIso = Join-Path $downloadDir $isoFileName

  try {
    Write-Host "Downloading ISO from $isoSourceUrl to $localIso ..."
    $headersWC = @{ "User-Agent" = $userAgent }
    Invoke-WebRequest -Uri $isoSourceUrl -OutFile $localIso -Headers $headersWC -UseBasicParsing -ErrorAction Stop
    Write-Host "Download complete."
  } catch {
    Write-Error "Download failed: $_"
    throw "ISO download failed. If Microsoft blocks automated download, place ISO in one of the agent paths listed and rerun."
  }
}

try {
  $sha = Get-FileHash -Path $localIso -Algorithm SHA256
  Write-Host "Local ISO SHA256: $($sha.Hash)"
} catch {
  Write-Warning "Could not compute SHA256: $_"
}

$uploadUri = "$apiBase/nodes/$node/storage/$isoStorage/upload?content=iso"
Write-Host "Uploading $localIso to Proxmox storage $isoStorage ... (this may take several minutes)"
$curl = "C:\\Windows\\System32\\curl.exe"
if (-Not (Test-Path $curl)) { $curl = "curl" }

$cmd = "$curl --silent --show-error --insecure -X POST -H `"Authorization: $authHeader`" -F `\"content=iso`\" -F `\"filename=@$localIso;type=application/octet-stream`\" `"$uploadUri`""
Write-Host "Running upload..."
$uploadOut = Invoke-Expression $cmd
Write-Host "Upload returned: $uploadOut"

Start-Sleep -Seconds 3
$resp2 = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
$items2 = $resp2.data
$exists2 = $items2 | Where-Object { $_.volid -like "*$isoFileName" }
if ($exists2) {
  Write-Host "ISO now present on Proxmox: $($exists2[0].volid)"
} else {
  Write-Error "Upload completed but ISO not visible in Proxmox storage listing."
  throw "Upload verification failed"
}

$isoVolid = $exists2[0].volid
Write-Output $isoVolid | Out-File -FilePath "..\\iso_volid.txt" -Encoding ascii

Write-Host "Ensure ISO stage finished successfully."
'''
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

$replacement = @"
boot_iso {
  iso_file = "$isoVolid"
  unmount  = true
}
"@

$content = Get-Content -Raw -Path $hclFile

$pattern = [regex]::Escape("boot_iso") + "\s*\{[^\}]*\}"
$newContent = [regex]::Replace($content, $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

if ($newContent -eq $content) {
  $newContent = $content + "`n`n" + $replacement
}

Set-Content -Path $hclFile -Value $newContent -Encoding UTF8

Write-Host "Packer HCL prepared to use iso_file: $isoVolid"
'''
        }
      }
    }

    stage('Packer Build') {
      steps {
        dir('packer') {
          withCredentials([
            string(credentialsId: 'PROXMOX_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_TOKEN_SECRET', variable: 'PM_SECRET'),
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
            string(credentialsId: 'PROXMOX_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_TOKEN_SECRET', variable: 'PM_SECRET')
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
  }

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
