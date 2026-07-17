pipeline {
    agent any

    environment {
        FLOCI_AZ_SERVICES_AKS_MOCKED = 'true'
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = 'true'
    }

    stages {
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
