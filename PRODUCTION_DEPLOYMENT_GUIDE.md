# Production Deployment Guide for **DevOps‑Pro**

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Azure Account & CLI Setup](#azure-account--cli-setup)
3. [Entra ID (Azure AD) Application Registration](#entra-id-application-registration)
4. [Container Registry (ACR) & Image Build](#container-registry-acr--image-build)
5. [Infrastructure as Code – Terraform](#infrastructure-as-code‑terraform)
6. [Deploy Backend Microservices to AKS](#deploy-backend-to-aks)
7. [Deploy Front‑end (React + Vite) to Azure Static Web Apps](#deploy-frontend)
8. [Configure Secrets & Environment Variables](#configure‑secrets‑environment)
9. [CI/CD Pipeline (Jenkins or GitHub Actions)](#cicd-pipeline)
10. [Domain, TLS & DNS](#domain‑tls‑dns)
11. [Monitoring & Logging](#monitoring‑logging)
12. [Verification Checklist](#verification-checklist)

---

### 1. Prerequisites

| Item | Minimum Version | Install / Verify |
|------|----------------|------------------|
| **Java** | 17+ | `java -version` |
| **Maven** | 3.9+ | `mvn -v` |
| **Node.js** | 20.x LTS | `node -v` |
| **Docker Desktop** | 24.x (WSL2 backend) | `docker version` |
| **Azure CLI** | 2.60+ | `az version` |
| **Terraform** | 1.7+ | `terraform -version` |
| **Git** | 2.45+ | `git --version` |
| **Jenkins** (optional) | 2.462+ | `java -jar jenkins.war` (if self‑hosted) |
| **PowerShell** | 7.x | `pwsh -v` |

> **NOTE**: All commands below assume a **PowerShell** terminal on Windows and that the repository root is `c:\Users\ahmad\IdeaProjects\devops-pro`.  

---

### 2. Azure Account & CLI Setup

```powershell
# Log in with your Azure student account
az login

# Set default subscription (replace <SUB_ID>)
az account set --subscription <SUB_ID>

# Verify you have the required resource providers registered
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Network
```

---

### 3. Entra ID (Azure AD) Application Registration

1. **Create a tenant‑wide app for the UI** (SPA)

   ```powershell
   # Create the app
   $uiApp = az ad app create `
       --display-name "devops-pro-ui" `
       --sign-in-audience AzureADMyOrg `
       --spa true `
       --redirect-uris "https://<YOUR_DOMAIN>/auth/callback"

   # Capture the Application (client) ID
   $uiClientId = $uiApp.appId
   ```

2. **Create a backend API app (confidential client)**

   ```powershell
   $apiApp = az ad app create `
       --display-name "devops-pro-api" `
       --sign-in-audience AzureADMyOrg `
       --web-redirect-uris "https://<YOUR_DOMAIN>/swagger-ui/oauth2-redirect.html" `
       --required-resource-accesses @manifest.json   # see step 6 for manifest

   $apiClientId = $apiApp.appId
   ```

3. **Create a client secret for the API app**

   ```powershell
   $secret = az ad app credential reset `
       --id $apiClientId `
       --append `
       --credential-description "devops-pro-api-secret" `
       --years 2

   $apiClientSecret = $secret.password
   ```

4. **Expose an API scope**

   ```powershell
   az ad app update `
       --id $apiClientId `
       --set api.oauth2PermissionScopes='[{"adminConsentDescription":"Full access to DevOps‑Pro API","adminConsentDisplayName":"DevOps‑Pro API","id":"$(uuidgen)","isEnabled":true,"type":"User","userConsentDescription":"Allow the app to call DevOps‑Pro API","userConsentDisplayName":"DevOps‑Pro API","value":"api.read"}]'
   ```

5. **Add required API permissions to the UI app**

   ```powershell
   az ad app permission add `
       --id $uiClientId `
       --api $apiClientId `
       --api-permissions $(az ad app show --id $apiClientId --query "api.oauth2PermissionScopes[0].id" -o tsv)=Scope
   ```

6. **Grant admin consent**

   ```powershell
   az ad app permission grant `
       --id $uiClientId `
       --api $apiClientId `
       --scope "api.read"
   ```

> **Store** `$uiClientId`, `$apiClientId` and `$apiClientSecret` – you will need them for the UI config and backend secrets.  

---

### 4. Container Registry (ACR) & Image Build

1. **Create an ACR instance**

   ```powershell
   az acr create --resource-group devops-pro-rg `
       --name devopsproacr `
       --sku Basic `
       --admin-enabled true
   ```

2. **Login to ACR**

   ```powershell
   az acr login --name devopsproacr
   ```

3. **Build & push backend images** (run from the repo root)

   ```powershell
   # Example for gateway-service (repeat for each microservice)
   cd gateway-service
   mvn clean package -DskipTests
   docker build -t devopsproacr.azurecr.io/gateway-service:latest .
   docker push devopsproacr.azurecr.io/gateway-service:latest
   cd ..
   ```

4. **Build & push the UI image**

   ```powershell
   cd dashboard-ui
   npm ci
   npm run build   # Vite builds to /dist
   docker build -t devopsproacr.azurecr.io/dashboard-ui:latest .
   docker push devopsproacr.azurecr.io/dashboard-ui:latest
   cd ..
   ```

---

### 5. Infrastructure as Code – Terraform

The Terraform code lives under `terraform/`.  
**Key resources:**

- **Resource Group** – `devops-pro-rg`
- **AKS Cluster** – `devops-pro-aks` (node pool: Standard_DS2_v2, 3 nodes)
- **Azure Container Registry** – imported from step 4 (data source)
- **Azure Key Vault** – holds client secret, JWT signing keys
- **App Service (Optional) / Azure Static Web Apps** – for UI
- **Azure DNS Zone** – if you own a custom domain

#### 5.1 Initialise & Apply

```powershell
cd terraform
terraform init
terraform fmt -check   # ensure style compliance
terraform validate
terraform plan -out=plan.out
terraform apply "plan.out"
```

> **Terraform variables** (`terraform/terraform.tfvars`) should contain:

```hcl
resource_group_name = "devops-pro-rg"
location            = "eastus"
acr_name            = "devopsproacr"
ui_client_id        = "<UI_CLIENT_ID>"
api_client_id       = "<API_CLIENT_ID>"
api_client_secret   = "<API_CLIENT_SECRET>"
tenant_id           = "<AZURE_TENANT_ID>"
domain_name         = "<YOUR_DOMAIN>"
```

> **Important**: Keep `terraform.tfvars` out of source control – add it to `.gitignore`.  

---

### 6. Deploy Backend Microservices to AKS

1. **Get AKS credentials**

   ```powershell
   az aks get-credentials --resource-group devops-pro-rg --name devops-pro-aks
   ```

2. **Create a namespace (optional)**

   ```bash
   kubectl create namespace devops-pro
   ```

3. **Deploy using the provided Helm chart** (`helm/` folder)

   ```bash
   helm upgrade --install gateway-service helm/gateway-service `
       --namespace devops-pro `
       --set image.repository=devopsproacr.azurecr.io/gateway-service `
       --set image.tag=latest `
       --set azure.tenantId=$tenant_id `
       --set azure.clientId=$api_client_id `
       --set azure.clientSecret=$api_client_secret
   ```

   Repeat for `config-service`, `pipeline-service`, … (the chart accepts the same values).

4. **Verify pods**

   ```bash
   kubectl get pods -n devops-pro
   ```

5. **Expose services via an Ingress controller** (NGINX is provisioned by Terraform)

   ```yaml
   # helm/gateway-service/values.yaml (excerpt)
   ingress:
     enabled: true
     className: nginx
     hosts:
       - host: api.<YOUR_DOMAIN>
         paths:
           - path: /
             pathType: Prefix
   ```

   Apply the chart again if you edited the values.

---

### 7. Deploy Front‑end (React + Vite)

Two production‑grade options:

#### 7.1 Azure Static Web Apps (recommended)

```powershell
az staticwebapp create `
    --name devops-pro-ui `
    --resource-group devops-pro-rg `
    --location eastus `
    --sku Standard `
    --source https://github.com/<YOUR_REPO>.git `
    --branch main `
    --app-location dashboard-ui `
    --output-location dist `
    --login-with-github   # if you prefer GitHub auth for CI
```

> **Configuration** – In the portal, go to **Configuration > Application Settings** and add:

| Name | Value |
|------|-------|
| `REACT_APP_CLIENT_ID` | `<UI_CLIENT_ID>` |
| `REACT_APP_TENANT_ID` | `<AZURE_TENANT_ID>` |
| `REACT_APP_AUTHORITY` | `https://login.microsoftonline.com/<AZURE_TENANT_ID>` |
| `REACT_APP_REDIRECT_URI` | `https://<YOUR_DOMAIN>/auth/callback` |

#### 7.2 AKS‑based Deployment (alternative)

```bash
kubectl apply -f helm/dashboard-ui/values.yaml \
    --namespace devops-pro \
    -l app=dashboard-ui \
    --set image.repository=devopsproacr.azurecr.io/dashboard-ui \
    --set image.tag=latest \
    --set env.REACT_APP_CLIENT_ID=$uiClientId \
    --set env.REACT_APP_TENANT_ID=$tenant_id
```

---

### 8. Configure Secrets & Environment Variables

- **Key Vault** (provisioned by Terraform) stores:
  - `api-client-secret` (value from step 3)
  - `jwt-signing-key` (RSA key pair)

- **Inject into AKS** using **Azure Key Vault Provider** (installed by Terraform):

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: devops-pro-secrets
  namespace: devops-pro
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    keyvaultName: "devops-pro-kv"
    objects: |
      array:
        - |
          objectName: api-client-secret
          objectType: secret
        - |
          objectName: jwt-signing-key
          objectType: secret
```

- **UI environment vars** are set in the Azure Static Web App **Configuration** page (see step 7.1).

---

### 9. CI/CD Pipeline

#### 9.1 Jenkins (self‑hosted)

| Stage | Command |
|-------|---------|
| **Checkout** | `git clone https://github.com/<YOUR_REPO>.git` |
| **Build Backend** | `cd gateway-service && mvn clean package -DskipTests` |
| **Docker Build & Push** | `docker build -t $ACR_URL/gateway-service:$(git rev-parse --short HEAD) . && docker push $ACR_URL/gateway-service:$(git rev-parse --short HEAD)` |
| **Deploy to AKS** | `helm upgrade --install gateway-service helm/gateway-service --set image.tag=$(git rev-parse --short HEAD)` |
| **Build UI** | `cd dashboard-ui && npm ci && npm run build` |
| **UI Deploy** | `az staticwebapp deployment create --name devops-pro-ui --resource-group devops-pro-rg --source . --artifact-location dashboard-ui/dist` |

*Jenkinsfile* (simplified) lives at `Jenkinsfile` – already present in the repo.

#### 9.2 GitHub Actions (alternative)

Create `.github/workflows/deploy.yml` with the same stages using Azure login action (`azure/login@v2`).

---

### 10. Domain, TLS & DNS

1. **Purchase / assign a custom domain** (e.g., `app.example.com`).
2. **Create an Azure DNS zone** (Terraform) and add an **A record** pointing to the Static Web App’s *custom domain* endpoint or the AKS Ingress public IP.

   ```hcl
   resource "azurerm_dns_a_record" "ui" {
     name                = "app"
     zone_name           = var.domain_name
     resource_group_name = var.resource_group_name
     ttl                 = 300
     records             = [azurerm_static_site.devops_pro_ui.default_hostname]
   }
   ```

3. **TLS** is provisioned automatically by Azure for both Static Web Apps and AKS Ingress (managed cert). No manual certificates required.

---

### 11. Monitoring & Logging

| Component | Azure Service |
|-----------|---------------|
| **Container logs** | Azure Monitor – Container Insights (enabled in AKS) |
| **Application logs** | Spring Boot `logging.file.name` → Azure Log Analytics (via `applicationinsights-spring-boot-starter`) |
| **Frontend errors** | Azure Application Insights (JS SDK) – add instrumentation key in UI config |
| **Metrics & Alerts** | Azure Monitor alerts on CPU, memory, pod restarts, ACR push failures |

Add the **Instrumentation Key** to the UI config (`REACT_APP_APPINSIGHTS_KEY`).

---

### 12. Verification Checklist

- [ ] Azure resources exist (`az group show -n devops-pro-rg`).
- [ ] ACR contains images for all microservices and UI (`az acr repository list -n devopsproacr`).
- [ ] AKS pods are **Running** and **Ready** (`kubectl get pods -n devops-pro`).
- [ ] Ingress endpoint reachable (`curl -k https://api.<YOUR_DOMAIN>/health`).
- [ ] UI loads over HTTPS at `https://<YOUR_DOMAIN>` and login succeeds (no `endpoints_resolution_error`).
- [ ] Entra ID token contains expected scopes (`api.read`).
- [ ] Application Insights dashboards show traffic and no error spikes.
- [ ] CI/CD pipeline passes on the main branch and deploys automatically.

---

#### 📎 Helpful Links (clickable)

- **Terraform folder**: [terraform](file:///c:/Users/ahmad/IdeaProjects/devops-pro/terraform)
- **Helm charts**: [helm/gateway-service](file:///c:/Users/ahmad/IdeaProjects/devops-pro/helm/gateway-service)
- **Backend Dockerfiles**:  
  - [gateway-service Dockerfile](file:///c:/Users/ahmad/IdeaProjects/devops-pro/gateway-service/Dockerfile)  
  - [config-service Dockerfile](file:///c:/Users/ahmad/IdeaProjects/devops-pro/config-service/Dockerfile)
- **UI Dockerfile**: [dashboard-ui Dockerfile](file:///c:/Users/ahmad/IdeaProjects/devops-pro/dashboard-ui/Dockerfile)
- **Jenkins pipeline**: [Jenkinsfile](file:///c:/Users/ahmad/IdeaProjects/devops-pro/Jenkinsfile)
- **Entra ID docs**: https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app

---

**You now have a full, production‑ready deployment workflow for DevOps‑Pro on Azure.** Follow the steps in order, adjust domain names and secrets to your environment, and you’ll have a secure, scalable, and monitorable cloud deployment.

*Happy deploying!*
