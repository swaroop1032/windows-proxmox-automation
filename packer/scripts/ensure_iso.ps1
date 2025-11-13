# packer/scripts/ensure_iso.ps1
# This script is executed on the Jenkins agent to ensure the ISO is available in Proxmox storage.
# It expects environment variables from Jenkins:
#   PROXMOX_API_BASE, PROXMOX_NODE, ISO_STORAGE, ISO_FILENAME, COMMON_ISO_PATHS, ISO_SOURCE_URL, UA
# And uses Jenkins-provided credentials injected as PM_ID and PM_SECRET (via withCredentials in Jenkinsfile).

# Read env vars
$apiBase      = $env:PROXMOX_API_BASE
$node         = $env:PROXMOX_NODE
$isoStorage   = $env:ISO_STORAGE
$isoFileName  = $env:ISO_FILENAME
$commonPaths  = $env:COMMON_ISO_PATHS
$isoSourceUrl = $env:ISO_SOURCE_URL
$userAgent    = $env:UA

if ($null -eq $env:PM_ID -or $null -eq $env:PM_SECRET) {
  Write-Error "PM_ID or PM_SECRET environment variables are not set. Ensure Jenkins withCredentials is configured correctly."
  exit 1
}

# Build auth header
if ($env:PM_ID -match '!') {
  $tokenId = $env:PM_ID
} else {
  $tokenId = "terraform@pam!$($env:PM_ID)"
}
$authHeader = "PVEAPIToken=$tokenId=$($env:PM_SECRET)"
$headers = @{ "Authorization" = $authHeader }

Write-Host ("Checking for ISO {0} in Proxmox storage {1} on node {2} via {3}" -f $isoFileName, $isoStorage, $node, $apiBase)

$isoFound = $false
if (-not [string]::IsNullOrWhiteSpace($apiBase)) {
  try {
    $listUri = "$apiBase/nodes/$node/storage/$isoStorage/content?content=iso"
    $resp = Invoke-RestMethod -Method Get -Uri $listUri -Headers $headers -UseBasicParsing -ErrorAction Stop
    $items = $resp.data
    $match = $items | Where-Object { $_.volid -like "*$isoFileName" }
    if ($match) {
      Write-Host ("ISO already present: {0}" -f $match[0].volid)
      $match[0].volid | Out-File -FilePath "..\\iso_volid.txt" -Encoding ascii
      exit 0
    }
  } catch {
    Write-Warning ("Could not list Proxmox storage content: {0}. Will attempt upload." -f $_)
  }
} else {
  Write-Warning "PROXMOX_API_BASE is empty; cannot list storage. Proceeding to upload attempt."
}

# Build list of possible local ISO locations
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

# Choose first existing candidate
$localIso = $localIsoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($localIso) {
  Write-Host ("Found local ISO on Jenkins agent: {0}" -f $localIso)
} else {
  # Attempt to download to cache
  $downloadDir = "C:\\jenkins_cache"
  if (-not (Test-Path $downloadDir)) { New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null }
  $localIso = Join-Path $downloadDir $isoFileName
  Write-Host ("Local ISO not found; attempting download from {0} to {1}" -f $isoSourceUrl, $localIso)
  try {
    Invoke-WebRequest -Uri $isoSourceUrl -OutFile $localIso -Headers @{ "User-Agent" = $userAgent } -UseBasicParsing -ErrorAction Stop
    Write-Host ("Downloaded ISO to {0}" -f $localIso)
  } catch {
    Write-Error ("Download failed: {0}" -f $_.Exception.Message)
    throw "ISO download failed. If Microsoft blocks automated download, place ISO in one of the agent paths and rerun."
  }
}

# Compute and log SHA256 (best-effort)
try {
  $sha = Get-FileHash -Path $localIso -Algorithm SHA256
  Write-Host ("Local ISO SHA256: {0}" -f $sha.Hash)
} catch {
  Write-Warning ("Could not compute SHA256: {0}" -f $_)
}

if ([string]::IsNullOrWhiteSpace($apiBase)) {
  Write-Error "PROXMOX_API_BASE is not set. Cannot upload ISO via API. Aborting."
  throw "PROXMOX_API_BASE missing"
}

# Upload via curl (multipart/form-data). Use --insecure if your Proxmox has self-signed certs.
$uploadUri = "$apiBase/nodes/$node/storage/$isoStorage/upload?content=iso"
Write-Host ("Uploading {0} to {1}" -f $localIso, $uploadUri)

$curlPath = "C:\\Windows\\System32\\curl.exe"
if (-not (Test-Path $curlPath)) { $curlPath = "curl" }

# Build args
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

Write-Host ("Running curl: {0}" -f ($args -join ' '))
& $curlPath @args

Start-Sleep -Seconds 3

# verify
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

Write-Host "Ensure ISO finished successfully."
