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
            string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PM_SECRET')
          ]) {
            powershell '''
# Read environment variables inside PowerShell
$apiBase      = $env:PROXMOX_API_BASE
$node         = $env:PROXMOX_NODE
$isoStorage   = $env:ISO_STORAGE
$isoFileName  = $env:ISO_FILENAME
$isoRefEnv    = $env:ISO_FILE_REF
$isoSourceUrl = $env:ISO_SOURCE_URL
$userAgent    = $env:UA
$commonPaths  = $env:COMMON_ISO_PATHS

# Build auth header using the Jenkins-provided credential variables (PM_ID, PM_SECRET)
if ($env:PM_ID -match '!') {
  $tokenId = $env:PM_ID
} else {
  $tokenId = "terraform@pam!$($env:PM_ID)"
}
$authHeader = "PVEAPIToken=$tokenId=$($env:PM_SECRET)"
$headers = @{ "Authorization" = $authHeader }

Write-Host ("API base: {0}" -f $apiBase)
Write-Host ("Node: {0}" -f $node)
Write-Host ("ISO storage: {0}" -f $isoStorage)
Write-Host ("ISO filename: {0}" -f $isoFileName)

# Try to list storage content
$isoExists = $null
if (-not [string]::IsNullOrWhiteSpace($apiBase)) {
  $listUri = "$apiBase/nodes/$node/storage/$isoStorage/content?content=iso"
  try {
    $resp = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
    $items = $resp.data
    $isoExists = $items | Where-Object { $_.volid -eq $isoRefEnv -or $_.volid -like "*$isoFileName" }
    if ($isoExists) {
      Write-Host ("ISO already present on Proxmox: {0}. Skipping upload." -f $isoExists[0].volid)
      $isoExists[0].volid | Out-File -FilePath "..\\iso_volid.txt" -Encoding ascii
      exit 0
    } else {
      Write-Host "ISO not found on Proxmox storage (will upload)."
    }
  } catch {
    Write-Warning ("Could not list Proxmox storage content: {0}. Will continue to attempt upload." -f $_)
  }
} else {
  Write-Warning "PROXMOX_API_BASE is empty — cannot check storage; will attempt upload."
}

# Prepare local ISO candidate list
$localIsoCandidates = @()
if ($env:ISO_LOCAL_PATH -and (Test-Path $env:ISO_LOCAL_PATH)) {
  $localIsoCandidates += $env:ISO_LOCAL_PATH
}

if (-not [string]::IsNullOrWhiteSpace($commonPaths)) {
  $parts = $commonPaths -split ';'
  foreach ($p in $parts) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $p2 = $p -replace '%USERNAME%', $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($p2)) { continue }
    $candidate = Join-Path $p2 $isoFileName
    $localIsoCandidates += $candidate
  }
}

$localIso = $localIsoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($localIso) {
  Write-Host ("Found local ISO on Jenkins agent: {0}" -f $localIso)
} else {
  $downloadDir = "C:\\jenkins_cache"
  if (-not (Test-Path $downloadDir)) { New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null }
  $localIso = Join-Path $downloadDir $isoFileName
  Write-Host ("No local ISO found. Attempting to download from {0} to {1} ..." -f $isoSourceUrl, $localIso)
  try {
    Invoke-WebRequest -Uri $isoSourceUrl -OutFile $localIso -Headers @{ "User-Agent" = $userAgent } -UseBasicParsing -ErrorAction Stop
    Write-Host ("Download complete: {0}" -f $localIso)
  } catch {
    Write-Error ("Download failed: {0}" -f $_)
    throw "ISO download failed. If Microsoft blocks automated download, place ISO in one of the agent paths and rerun."
  }
}

try {
  $sha = Get-FileHash -Path $localIso -Algorithm SHA256
  Write-Host ("Local ISO SHA256: {0}" -f $sha.Hash)
} catch {
  Write-Warning ("Could not compute SHA256: {0}" -f $_)
}

if ([string]::IsNullOrWhiteSpace($apiBase)) {
  Write-Error "PROXMOX_API_BASE is not set. Cannot upload ISO. Aborting."
  throw "PROXMOX_API_BASE missing"
}

$uploadUri = "$apiBase/nodes/$node/storage/$isoStorage/upload?content=iso"
Write-Host ("Uploading {0} to Proxmox storage {1} via API..." -f $localIso, $isoStorage)

# Build curl arguments and run without creating a single big quoted string (avoids quoting issues)
$curlPath = "C:\\Windows\\System32\\curl.exe"
if (-not (Test-Path $curlPath)) { $curlPath = "curl" }

$args = @(
  "--silent",
  "--show-error",
  "--insecure",
  "-X", "POST",
  "-H", ("Authorization: {0}" -f $authHeader),
  "-F", "content=iso",
  ("-F", ("filename=@{0};type=application/octet-stream" -f $localIso)),
  $uploadUri
)

Write-Host ("Running curl with arguments: {0}" -f ($args -join ' '))
& $curlPath @args

# After upload, verify
Start-Sleep -Seconds 3
$listUri = "$apiBase/nodes/$node/storage/$isoStorage/content?content=iso"
$resp2 = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
$items2 = $resp2.data
$exists2 = $items2 | Where-Object { $_.volid -like "*$isoFileName" }
if ($exists2) {
  Write-Host ("ISO now present on Proxmox: {0}" -f $exists2[0].volid)
  $exists2[0].volid | Out-File -FilePath "..\\iso_volid.txt" -Encoding ascii
} else {
  Write-Error "Upload finished but ISO not found in Proxmox listing."
  throw "Upload verification failed"
}

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
} // end pipeline
