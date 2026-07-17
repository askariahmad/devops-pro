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

#### Option A: Using Azure CLI
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

#### Option B: Using Azure Portal (UI)
1. **Log in to Azure Portal**: Go to [portal.azure.com](https://portal.azure.com) and log in with your Azure account.
2. **Set Default Subscription (Optional)**:
   - In the top right, click your profile picture → **Switch directory** (if needed)
   - To confirm your active subscription, search for "Subscriptions" in the top search bar
3. **Register Resource Providers**:
   - Search for "Subscriptions" → select your subscription
   - In the left menu, under **Settings**, click **Resource providers**
   - Search for `Microsoft.ContainerService`, select it, click **Register**
   - Search for `Microsoft.Web`, select it, click **Register**
   - Search for `Microsoft.Network`, select it, click **Register**
   - Wait for registration status to show **Registered** (can take a few minutes)

---

### 3. Entra ID (Azure AD) Application Registration

#### Option A: Using Azure CLI
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

---

#### Option B: Using Azure Portal (UI)
1. **Create the UI App Registration (SPA)**
   - Search for "App registrations" in the Azure portal → click **New registration**
   - **Name**: `devops-pro-ui`
   - **Supported account types**: Choose based on your needs (single-tenant, multi-tenant, or multi-tenant + personal accounts)
   - **Redirect URI**:
     - Dropdown: Select **Single-page application (SPA)**
     - URL: Enter `https://<YOUR_DOMAIN>/auth/callback`
   - Click **Register**
   - On the **Overview** page, copy the **Application (client) ID** and save it as `$uiClientId`

2. **Create the API App Registration**
   - Go back to "App registrations" → click **New registration**
   - **Name**: `devops-pro-api`
   - **Supported account types**: Choose the same option as your UI app
   - **Redirect URI**:
     - Dropdown: Select **Web**
     - URL: Enter `https://<YOUR_DOMAIN>/swagger-ui/oauth2-redirect.html`
   - Click **Register**
   - On the **Overview** page, copy the **Application (client) ID** and save it as `$apiClientId`

3. **Create a Client Secret for the API App**
   - Open the `devops-pro-api` app registration
   - In the left menu, click **Certificates & secrets**
   - Click **New client secret**
   - Enter a description like `devops-pro-api-secret`
   - Choose an expiration (e.g., 24 months)
   - Click **Add**
   - Immediately copy the **Value** (not the Secret ID) and save it as `$apiClientSecret` – you won't be able to see it again!

4. **Expose an API Scope on the API App**
   - Open the `devops-pro-api` app registration
   - In the left menu, click **Expose an API**
   - Next to "Application ID URI", click **Set** → accept the default URI (or customize) → click **Save**
   - Click **Add a scope**
     - **Scope name**: `api.read`
     - **Who can consent**: Admins and users
     - **Admin consent display name**: `DevOps-Pro API`
     - **Admin consent description**: `Full access to DevOps-Pro API`
     - **User consent display name**: `DevOps-Pro API`
     - **User consent description**: `Allow the app to call DevOps-Pro API`
     - **State**: Enabled
   - Click **Add scope**

5. **Add API Permissions to the UI App**
   - Open the `devops-pro-ui` app registration
   - In the left menu, click **API permissions** → **Add a permission**
   - Select **My APIs** → choose `devops-pro-api`
   - Select **Delegated permissions** → check the `api.read` scope
   - Click **Add permissions**

6. **Grant Admin Consent**
   - Still on the UI app's **API permissions** page
   - Click **Grant admin consent for Default Directory** → click **Yes** to confirm

> **Store** `$uiClientId`, `$apiClientId` and `$apiClientSecret` – you will need them for the UI config and backend secrets.  

---

### 4. Container Registry (ACR) & Image Build

#### Option A: Using Azure CLI
1. **Create an ACR instance**
   - **Note about Azure region policies**: Your subscription may have an Azure Policy that restricts which regions you can deploy to! To find allowed regions, go to the Azure portal → search for "Policy" → check "Assignments"!

   ```powershell
   az acr create --resource-group devops-pro-rg `
       --name devopsproacr `
       --sku Basic `
       --admin-enabled true `
       --location <allowed-region>  # Replace with an allowed region from your Azure Policy!
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

#### Option B: Using Azure Portal (UI) + CLI for image builds
1. **Create a Resource Group (if not exists)**:
   - **Note about Azure region policies**: Your subscription may have an Azure Policy that restricts which regions you can deploy to! To find allowed regions, go to the Azure portal → search for "Policy" → check "Assignments"!
   - **Note about resource group location**: You can't change the location of an existing resource group! If you created it in the wrong region, delete it and create a new one in the allowed region!
   - Search for "Resource groups" → click **Create**
   - **Resource group name**: `devops-pro-rg`
   - **Region**: Choose an **allowed region** (check your Azure Policy first)
   - Click **Review + create** → **Create**

2. **Create an ACR instance**:
   - Search for "Container registries" → click **Create**
   - **Basics Tab**:
     - **Subscription**: Select your subscription
     - **Resource group**: Select `devops-pro-rg`
     - **Registry name**: Enter a unique name (e.g., `devopsproacr`; must be 5-50 characters, lowercase letters/numbers)
     - **Location**: Choose an **allowed region** (same as your resource group, check your Azure Policy first)
     - **Pricing plan**: Basic (dev/test), Standard (production), or Premium (advanced features like geo-replication, availability zones)
     - **Domain name label scope**: Choose **No reuse** (recommended—your registry name/DNS label is globally unique and can't be used by anyone else)
     - **Availability zones** (only if Premium SKU is selected): Enable to make your registry zone-redundant (available in regions with AZ support)
   - **Encryption Tab** (optional): Leave as default (Microsoft-managed keys)
   - **Networking Tab** (optional): Leave as default (Public access)
   - **Advanced Tab**:
     - **Admin user**: Enable (for `az acr login` with username/password; for production, use managed identities instead)
     - **Role assignment permissions mode**: Choose either:
       - **RBAC Registry Permissions** (default/recommended): Only Azure RBAC applies to the entire registry (simpler, good for basic deployments)
       - **RBAC Registry + ABAC Repository Permissions**: Use both Azure RBAC and ABAC for granular repository-level permissions (good for complex scenarios with multiple teams/repos)
   - **Tags Tab** (optional): Add tags to organize your resources (key-value pairs)
     - Example tags:
       - `Environment`: `Production`
       - `Project`: `DevOps-Pro`
       - `Department`: `Engineering`
   - Click **Review + create** → **Create**

3. **Login to ACR (CLI required)**:
   ```powershell
   az acr login --name devopsproacr
   ```

4. **Build & push images (same as CLI option, steps 3-4)**:
   ```powershell
   # Example for gateway-service (repeat for each microservice)
   cd gateway-service
   mvn clean package -DskipTests
   docker build -t devopsproacr.azurecr.io/gateway-service:latest .
   docker push devopsproacr.azurecr.io/gateway-service:latest
   cd ..

   # Build & push UI
   cd dashboard-ui
   npm ci
   npm run build
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

##### Option A: Using Azure CLI
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

##### Option B: Using Azure Portal (UI)
1. **Create a Static Web App**:
   - Search for "Static Web Apps" in the Azure portal → click **Create**
   - **Subscription**: Select your subscription
   - **Resource group**: Select `devops-pro-rg`
   - **Name**: Enter `devops-pro-ui`
   - **Plan type**: Standard
   - **Region for Azure Functions API and staging environments**: Choose a region (e.g., East US)
   - **Source**: Select **Other** (for manual deployment) or **GitHub** (for CI/CD)
     - If GitHub: Sign in, select your repository, branch, app location (`dashboard-ui`), output location (`dist`)
   - Click **Review + create** → **Create**

2. **Configure Environment Variables**:
   - After deployment completes, go to the Static Web App resource
   - In the left menu, under **Settings**, click **Configuration**
   - Click **Add** and add the following application settings:

| Name | Value |
|------|-------|
| `REACT_APP_CLIENT_ID` | `<UI_CLIENT_ID>` |
| `REACT_APP_TENANT_ID` | `<AZURE_TENANT_ID>` |
| `REACT_APP_AUTHORITY` | `https://login.microsoftonline.com/<AZURE_TENANT_ID>` |
| `REACT_APP_REDIRECT_URI` | `https://<YOUR_DOMAIN>/auth/callback` |

   - Click **Save** to apply changes

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
