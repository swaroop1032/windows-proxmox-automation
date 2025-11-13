pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Packer Build') {
      steps {
        dir('packer') {
          withCredentials([
            string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PROXMOX_API_TOKEN_ID'),
            string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PROXMOX_API_TOKEN_SECRET'),
            string(credentialsId: 'WIN_ADMIN_PASSWORD', variable: 'WIN_ADMIN_PASSWORD')
          ]) {
            powershell 'packer init .'
            powershell "packer build -var proxmox_url='https://192.168.31.180:8006/' -var pm_token_id=$PROXMOX_API_TOKEN_ID -var pm_token_secret=$PROXMOX_API_TOKEN_SECRET -var win_admin_pass=$WIN_ADMIN_PASSWORD windows11.pkr.hcl"
          }
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        dir('terraform') {
          withCredentials([
            string(credentialsId: 'PROXMOX_API_TOKEN_ID', variable: 'PROXMOX_API_TOKEN_ID'),
            string(credentialsId: 'PROXMOX_API_TOKEN_SECRET', variable: 'PROXMOX_API_TOKEN_SECRET')
          ]) {
            powershell 'terraform init'
            powershell "terraform apply -auto-approve -var pm_api_token_id=$PROXMOX_API_TOKEN_ID -var pm_api_token_secret=$PROXMOX_API_TOKEN_SECRET"
          }
        }
      }
    }
  }
}

