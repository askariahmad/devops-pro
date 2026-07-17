pipeline {
    agent any

    environment {
        FLOCI_AZ_SERVICES_AKS_MOCKED = 'true'
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = 'true'
    }

    options {
        skipDefaultCheckout()
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout([$class: 'GitSCM', 
                    branches: [[name: '*/feat/azure-migration']], 
                    extensions: [[$class: 'SubmoduleOption', recursiveSubmodules: true, disableSubmodules: false, trackingSubmodules: false]], 
                    userRemoteConfigs: [[url: 'file:///workspace']]
                ])
            }
        }

        stage('Bootstrap Tools') {
            steps {
                sh '''
                    # Check if pwsh is missing
                    if ! command -v pwsh &> /dev/null; then
                        echo "Installing PowerShell Core..."
                        curl -L -o powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/powershell-7.4.2-linux-x64.tar.gz
                        mkdir -p /opt/microsoft/powershell/7
                        tar zxf powershell.tar.gz -C /opt/microsoft/powershell/7
                        chmod +x /opt/microsoft/powershell/7/pwsh
                        ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
                        rm powershell.tar.gz
                    fi

                    # Check if terraform is missing
                    if ! command -v terraform &> /dev/null; then
                        echo "Installing Terraform..."
                        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" | tee /etc/apt/sources.list.d/hashicorp.list
                        apt-get update && apt-get install -y terraform
                    fi

                    # Check if kubectl is missing
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        mv kubectl /usr/local/bin/kubectl
                    fi

                    # Check if npm or mvn are missing
                    if ! command -v npm &> /dev/null || ! command -v mvn &> /dev/null; then
                        echo "Installing Node.js, npm, and Maven..."
                        apt-get update && apt-get install -y nodejs npm maven
                    fi

                    # Configure Git safe directory & protocols
                    git config --global --add safe.directory '*'
                    git config --global protocol.file.allow always
                '''
            }
        }

        stage('Verify Prerequisites') {
            steps {
                sh 'pwsh ./deploy.ps1 -Cloud azure -Stage Verify'
            }
        }

        stage('Build & Pack in Parallel') {
            parallel {
                stage('Build config-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName config-service'
                    }
                }
                stage('Build gateway-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName gateway-service'
                    }
                }
                stage('Build incident-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName incident-service'
                    }
                }
                stage('Build log-analyzer-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName log-analyzer-service'
                    }
                }
                stage('Build log-collector-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName log-collector-service'
                    }
                }
                stage('Build notification-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName notification-service'
                    }
                }
                stage('Build repo-scanner-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName repo-scanner-service'
                    }
                }
                stage('Build dashboard-ui') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage BuildService -ServiceName dashboard-ui'
                    }
                }
            }
        }

        stage('Initialize Local Emulator') {
            steps {
                sh 'pwsh ./deploy.ps1 -Cloud azure -Stage Emulator'
            }
        }

        stage('Conflict Cleanup') {
            steps {
                sh 'pwsh ./deploy.ps1 -Cloud azure -Stage Clean'
            }
        }

        stage('Deploy IaC Infrastructure') {
            steps {
                sh 'pwsh ./deploy.ps1 -Cloud azure -Stage Terraform'
            }
        }

        stage('Verify Rollout in Parallel') {
            parallel {
                stage('Monitor config-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName config-service'
                    }
                }
                stage('Monitor gateway-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName gateway-service'
                    }
                }
                stage('Monitor incident-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName incident-service'
                    }
                }
                stage('Monitor log-analyzer-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName log-analyzer-service'
                    }
                }
                stage('Monitor log-collector-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName log-collector-service'
                    }
                }
                stage('Monitor notification-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName notification-service'
                    }
                }
                stage('Monitor repo-scanner-service') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName repo-scanner-service'
                    }
                }
                stage('Monitor dashboard-ui') {
                    steps {
                        sh 'pwsh ./deploy.ps1 -Cloud azure -Stage MonitorService -ServiceName dashboard-ui'
                    }
                }
            }
        }
    }
}
