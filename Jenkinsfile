pipeline {
  agent any

  environment {
    TF_IN_AUTOMATION = "1"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Packer Build') {
      steps {
        dir('packer') {
          // Credentials: change these IDs if your Jenkins creds use different IDs
          withCredentials([
            string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PM_ID'),
            string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PM_SECRET'),
            string(credentialsId: 'WIN_ADMIN_PASSWORD', variable: 'WINPASS')
          ]) {
            // Use triple-single-quotes to avoid Groovy string interpolation of secrets.
            powershell '''
# -------------------------
# Packer build script (PowerShell)
# -------------------------
Write-Host "Starting Packer init & build..."

# Decide proxmox username: accept either full form "user@realm!tokenid" in PM_ID
# or just the token id in PM_ID (we'll prepend terraform@pam!)
if ($env:PM_ID -match '!') {
  $proxmox_username = $env:PM_ID
} else {
  $proxmox_username = "terraform@pam!$($env:PM_ID)"
}

Write-Host "Using Proxmox username: $proxmox_username"

# Initialize packer (downloads plugins)
Write-Host "Running: packer init ."
packer init .

if ($LASTEXITCODE -ne 0) {
  Write-Error "packer init failed (exit $LASTEXITCODE). Aborting."
  exit $LASTEXITCODE
}

# Run packer build. We pass sensitive values via environment variables within PowerShell ($env:PM_SECRET / $env:WINPASS)
# Packer variable names: proxmox_username, proxmox_token, winrm_password
Write-Host "Running: packer build ..."
packer build `
  -var "proxmox_username=$proxmox_username" `
  -var "proxmox_token=$($env:PM_SECRET)" `
  -var "winrm_password=$($env:WINPASS)" `
  windows11.pkr.hcl

if ($LASTEXITCODE -ne 0) {
  Write-Error "packer build failed (exit $LASTEXITCODE). Aborting pipeline."
  exit $LASTEXITCODE
}

Write-Host "Packer build completed successfully."
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
# -------------------------
# Terraform apply script (PowerShell)
# -------------------------
Write-Host "Starting Terraform init & apply..."

# Same token id handling as in Packer stage
if ($env:PM_ID -match '!') {
  $tf_token_id = $env:PM_ID
} else {
  $tf_token_id = "terraform@pam!$($env:PM_ID)"
}

Write-Host "Using Proxmox token id: $tf_token_id"

# Init terraform
terraform init -input=false

if ($LASTEXITCODE -ne 0) {
  Write-Error "terraform init failed (exit $LASTEXITCODE). Aborting."
  exit $LASTEXITCODE
}

# Apply terraform using -var to pass token values to provider
terraform apply -auto-approve `
  -var "pm_api_token_id=$tf_token_id" `
  -var "pm_api_token_secret=$($env:PM_SECRET)"

if ($LASTEXITCODE -ne 0) {
  Write-Error "terraform apply failed (exit $LASTEXITCODE)."
  exit $LASTEXITCODE
}

Write-Host "Terraform apply completed successfully."
'''
          }
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished. Check above output for success/failure details."
    }
    success {
      echo "Pipeline succeeded — template should be created and VM provisioned."
    }
    failure {
      echo "Pipeline failed — inspect logs above. If Packer fails, check WinRM and plugin schema; if Terraform fails, check provider and token permissions."
    }
  }
}
