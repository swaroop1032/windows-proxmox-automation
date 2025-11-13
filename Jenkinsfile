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
# Read env vars directly in PowerShell
$apiBase      = $env:PROXMOX_API_BASE
$node         = $env:PROXMOX_NODE
$isoStorage   = $env:ISO_STORAGE
$isoFileName  = $env:ISO_FILENAME
$isoRefEnv    = $env:ISO_FILE_REF
$isoSourceUrl = $env:ISO_SOURCE_URL
$userAgent    = $env:UA
$commonPaths  = $env:COMMON_ISO_PATHS

# Construct token auth header
if ($env:PM_ID -match '!') {
  $tokenId = $env:PM_ID
} else {
  $tokenId = "terraform@pam!$($env:PM_ID)"
}
$authHeader = "PVEAPIToken=$tokenId=$($env:PM_SECRET)"
$headers = @{ "Authorization" = $authHeader }

Write-Host "API base: $apiBase"
Write-Host "Node: $node"
Write-Host "ISO storage: $isoStorage"
Write-Host "ISO file name: $isoFileName"
Write-Host "ISO file ref (env): $isoRefEnv"

# Try to list storage content in Proxmox (if apiBase is valid)
$isoExists = $null
if ([string]::IsNullOrWhiteSpace($apiBase)) {
  Write-Warning "PROXMOX_API_BASE is empty — will skip content check and attempt upload later."
} else {
  $listUri = "$apiBase/nodes/$node/storage/$isoStorage/content?content=iso"
  try {
    $resp = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
    $items = $resp.data
    $isoExists = $items | Where-Object { $_.volid -eq $isoRefEnv -or $_.volid -like "*$isoFileName" }
    if ($isoExists) {
      Write-Host "ISO already present on Proxmox: $($isoExists[0].volid). Skipping upload."
      # Save volid for later stages
      $isoExists[0].volid | Out-File -FilePath "..\\iso_volid.txt" -Encoding ascii
      exit 0
    } else {
      Write-Host "ISO not found on Proxmox storage (will upload)."
    }
  } catch {
    Write-Warning "Could not list Proxmox storage content: $_. Will continue to attempt upload."
  }
}

# Build local candidate paths (ISO_LOCAL_PATH is optional)
$localIsoCandidates = @()
if ($env:ISO_LOCAL_PATH -and (Test-Path $env:ISO_LOCAL_PATH)) {
  $localIsoCandidates += $env:ISO_LOCAL_PATH
}

if (-not [string]::IsNullOrWhiteSpace($commonPaths)) {
  $parts = $commonPaths -split ';'
  foreach ($p in $parts) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    # replace %USERNAME% placeholder if present
    $p2 = $p -replace '%USERNAME%', $env:USERNAME
    if ([string]::IsNullOrWhiteSpace($p2)) { continue }
    $candidate = Join-Path $p2 $isoFileName
    $localIsoCandidates += $candidate
  }
}

# Find the first existing local ISO candidate
$localIso = $localIsoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($localIso) {
  Write-Host "Found local ISO on Jenkins agent: $localIso"
} else {
  # Download to Jenkins cache
  $downloadDir = "C:\\jenkins_cache"
  if (-not (Test-Path $downloadDir)) { New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null }
  $localIso = Join-Path $downloadDir $isoFileName
  Write-Host "No local ISO found. Downloading from $isoSourceUrl to $localIso ..."
  try {
    Invoke-WebRequest -Uri $isoSourceUrl -OutFile $localIso -Headers @{ "User-Agent" = $userAgent } -UseBasicParsing -ErrorAction Stop
    Write-Host "Download complete: $localIso"
  } catch {
    Write-Error "Download failed: $_"
    throw "ISO download failed. If Microsoft blocks automated download, place ISO in one of the agent paths and rerun."
  }
}

# Compute checksum (informational)
try {
  $sha = Get-FileHash -Path $localIso -Algorithm SHA256
  Write-Host "Local ISO SHA256: $($sha.Hash)"
} catch {
  Write-Warning "Could not compute SHA256: $_"
}

# Upload to Proxmox via API using curl
if ([string]::IsNullOrWhiteSpace($apiBase)) {
  Write-Warning "PROXMOX_API_BASE empty — cannot upload via API. Ensure PROXMOX_API_BASE is set or upload ISO manually."
  throw "PROXMOX_API_BASE empty"
}

$uploadUri = "$apiBase/nodes/$node/storage/$isoStorage/upload?content=iso"
Write-Host "Uploading $localIso to Proxmox storage $isoStorage via API..."
$curl = "C:\\Windows\\System32\\curl.exe"
if (-not (Test-Path $curl)) { $curl = "curl" }

$cmd = "$curl --silent --show-error --insecure -X POST -H `"Authorization: $authHeader`" -F `\"content=iso`\" -F `\"filename=@$localIso;type=application/octet-stream`\" `"$uploadUri`""
Write-Host "Running upload command (this may take long)..."
$uploadOut = Invoke-Expression $cmd
Write-Host "Upload returned: $uploadOut"

Start-Sleep -Seconds 3
# verify upload
$listUri = "$apiBase/nodes/$node/storage/$isoStorage/content?content=iso"
$resp2 = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
$items2 = $resp2.data
$exists2 = $items2 | Where-Object { $_.volid -like "*$isoFileName" }
if ($exists2) {
  Write-Host "ISO now present on Proxmox: $($exists2[0].volid)"
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


    stage('Prepare Packer (use uploaded ISO)') {
      steps {
        dir('packer') {
          powershell '''
# This script replaces the existing boot_iso { ... } block in the packer HCL by scanning lines and counting braces.
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
    # No boot_iso block — append the new block
    $replacementBlock = @(
        "boot_iso {",
        "  iso_file = ""$isoVolid""",
        "  unmount  = true",
        "}"
    )
    $newContent = $lines + $replacementBlock
    $newContent | Set-Content -Path $hclFile -Encoding UTF8
    Write-Host "No existing boot_iso found. Appended iso block."
    exit 0
}

# Find matching closing brace by counting braces
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

# Build new content: lines before startIndex + replacement block + lines after endIndex
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

Write-Host "Replaced boot_iso block with iso_file: $isoVolid"
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



