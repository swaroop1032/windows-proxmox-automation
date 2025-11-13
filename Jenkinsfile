pipeline {
    agent any

    environment {
        # Jenkins host path where the original ISO is stored
        ORIGINAL_ISO_PATH = "/var/jenkins_home/isos/Win11_23H2_English_x64.iso"
        # Name of the custom ISO to create
        CUSTOM_ISO_NAME = "Win11-Custom.iso"
        # Proxmox details
        PROXMOX_HOST = "192.168.1.10"
        PROXMOX_ISO_PATH = "/var/lib/vz/template/iso"
        # Packer template path
        PACKER_DIR = "packer"
        # Terraform configuration path
        TERRAFORM_DIR = "terraform"
    }

    stages {

        stage('Checkout Code') {
            steps {
                echo "Checking out GitHub repository..."
                checkout scm
            }
        }

        stage('Build Custom ISO') {
            steps {
                echo "Building custom Windows ISO with autounattend.xml..."
                powershell '''
                    $SourceISO = "${ORIGINAL_ISO_PATH}"
                    $OutputISO = "${WORKSPACE}\\${CUSTOM_ISO_NAME}"
                    $UnattendFile = "${WORKSPACE}\\autounattend.xml"
                    # PowerShell script to inject autounattend.xml into ISO
                    .\\packer\\scripts\\build-iso.ps1 -SourceISO $SourceISO -OutputISO $OutputISO -UnattendFile $UnattendFile
                '''
            }
        }

        stage('Upload ISO to Proxmox') {
            steps {
                echo "Uploading custom ISO to Proxmox..."
                sshagent(credentials: ['proxmox-ssh']) {
                    sh '''
                        scp -o StrictHostKeyChecking=no ${WORKSPACE}/${CUSTOM_ISO_NAME} \
                        root@${PROXMOX_HOST}:${PROXMOX_ISO_PATH}/${CUSTOM_ISO_NAME}
                    '''
                }
            }
        }

        stage('Build Packer Template') {
            steps {
                echo "Running Packer to create Windows template..."
                dir("${PACKER_DIR}") {
                    sh '''
                        packer init .
                        packer build -force -var "iso_file=local:iso/${CUSTOM_ISO_NAME}" windows11.json
                    '''
                }
            }
        }

        stage('Deploy VM with Terraform') {
            steps {
                echo "Deploying VM from template using Terraform..."
                dir("${TERRAFORM_DIR}") {
                    sh '''
                        terraform init
                        terraform apply -auto-approve
                    '''
                }
            }
        }

        stage('Cleanup Workspace') {
            steps {
                echo "Cleaning up temporary files..."
                sh "rm -f ${WORKSPACE}/${CUSTOM_ISO_NAME}"
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
        }
        success {
            echo "Deployment successful!"
        }
        failure {
            echo "Pipeline failed. Check logs for errors."
        }
    }
}
