# Production Deployment Guide for **DevOps‑Pro**

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Azure Account & CLI Setup](#azure-account--cli-setup)
3. [Entra ID (Azure AD) Application Registration](#entra-id-application-registration)
4.[Infrastructure as Code – Terraform](#infrastructure-as-code‑terraform)
5. [Container Registry (ACR) & Image Build](#container-registry-acr--image-build)
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
az provider register --namespace Microsoft.ContainerService  # For AKS
az provider register --namespace Microsoft.ContainerRegistry # For ACR
az provider register --namespace Microsoft.Cache            # For Redis Cache
az provider register --namespace Microsoft.Web             # For Static Web Apps
az provider register --namespace Microsoft.Network          # For networking resources
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

This project uses Terraform to provision all Azure resources (resource group, ACR, AKS, and Managed Redis). All infrastructure is defined as code in the `/terraform` directory.

#### What Terraform Creates for Production
Terraform provisions these **key Azure resources** for production deployments:

| Resource | Purpose | Configuration Details |
|----------|---------|-----------------------|
| **Resource Group** | Logical container for all resources | Named `${var.project_name}-rg` in your chosen region |
| **AKS Cluster** | Hosts all backend microservices | `${var.project_name}-aks` with standard node pool (2 nodes by default, Standard_D2s_v3) |
| **ACR** | Container registry for all microservice/UI images | `${var.project_name}acr` with Standard SKU, admin user enabled, automatically attached to AKS |
| **Azure Managed Redis** | In-memory caching for session state and data | `${var.project_name}-redis` Balanced_B3 SKU, default database on port 10000 |
| **Kubernetes Resources** | Prepares your AKS cluster for application deployment | Creates a dedicated `devopspro` namespace and Redis connection secrets in `kubernetes.tf` |

#### Terraform Configuration Files
The following files are included:
- `main.tf`: Core Azure resources and provider configuration
- `variables.tf`: Configurable variables with sensible defaults
- `kubernetes.tf`: Kubernetes provider setup and namespace/secrets creation
- `.gitignore`: Terraform-specific ignores for state files and sensitive data
- `terraform.tfvars.template`: Template for your configuration values

#### Prerequisites
- Terraform 1.0+ installed locally
- Azure CLI authenticated with `az login`
- A dedicated service principal for Terraform authentication

#### 1. Create a Service Principal for Terraform
First, create a service principal that Terraform will use to deploy resources:
```powershell
$sp = az ad sp create-for-rbac --name "devops-pro-terraform-sp" --role "Contributor" --scopes "/subscriptions/$(az account show --query id -o tsv)"
$azure_client_id = $sp.appId
$azure_client_secret = $sp.password
$azure_tenant_id = $sp.tenant
$azure_subscription_id = az account show --query id -o tsv
```

#### 2. Configure Terraform Variables
Copy the template file and fill in your values:
```powershell
cd terraform
cp terraform.tfvars.template terraform.tfvars
# Edit terraform.tfvars with your values:
```

Example `terraform.tfvars`:
```hcl
project_name = "devopspro"
azure_tenant_id       = "your-azure-tenant-id"
azure_subscription_id = "your-azure-subscription-id"
azure_client_id       = "your-azure-service-principal-client-id"
azure_client_secret   = "your-azure-service-principal-client-secret"
azure_region = "eastus"
azure_metadata_host = "https://management.azure.com"
aks_node_count = 3
```

#### 3. Run Terraform Workflow
```powershell
# Initialize Terraform (download providers, set up backend)
terraform init

# Format all Terraform files in the directory
terraform fmt -recursive

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Apply configuration (create resources)
terraform apply
```

#### 4. Terraform Outputs
After successful deployment, Terraform will output critical values:
- `resource_group_name`: Name of the created resource group
- `acr_login_server`: ACR login server (for docker pushes)
- `redis_hostname` / `redis_ssl_port` / `redis_primary_access_key`: Managed Redis connection details
- `aks_kubeconfig`: Command to retrieve AKS credentials

---

### 5. Container Registry (ACR) & Image Build

After running Terraform to create your infrastructure, retrieve your ACR details and build/push your microservice container images.

#### 5.1 Retrieve ACR details and Login
```powershell
cd terraform
# Get your ACR login server (output from Terraform)
$acrLoginServer = terraform output -raw acr_login_server
# Extract the ACR name from the login server (everything before .azurecr.io)
$acrName = $acrLoginServer.Split('.')[0]

# Log in to your registry
az acr login --name $acrName
```

#### 5.2 Build & Push Microservice Container Images
Run the following commands from the repository root (run `cd ..` first if you are still in the `terraform` directory):

```powershell
# Go back to repository root
cd ..

# config-service
docker build -t "$acrLoginServer/config-service:latest" -f config-service/Dockerfile .
docker push "$acrLoginServer/config-service:latest"

# gateway-service
docker build -t "$acrLoginServer/gateway-service:latest" -f gateway-service/Dockerfile .
docker push "$acrLoginServer/gateway-service:latest"

# incident-service
docker build -t "$acrLoginServer/incident-service:latest" -f incident-service/Dockerfile .
docker push "$acrLoginServer/incident-service:latest"

# log-analyzer-service
docker build -t "$acrLoginServer/log-analyzer-service:latest" -f log-analyzer-service/Dockerfile .
docker push "$acrLoginServer/log-analyzer-service:latest"

# log-collector-service
docker build -t "$acrLoginServer/log-collector-service:latest" -f log-collector-service/Dockerfile .
docker push "$acrLoginServer/log-collector-service:latest"

# notification-service
docker build -t "$acrLoginServer/notification-service:latest" -f notification-service/Dockerfile .
docker push "$acrLoginServer/notification-service:latest"

# repo-scanner-service
docker build -t "$acrLoginServer/repo-scanner-service:latest" -f repo-scanner-service/Dockerfile .
docker push "$acrLoginServer/repo-scanner-service:latest"

# Build & push React Dashboard UI
cd dashboard-ui
npm ci
npm run build   # Vite builds to /dist
docker build -t "$acrLoginServer/dashboard-ui:latest" .
docker push "$acrLoginServer/dashboard-ui:latest"
cd ..
```

---

### 6. Deploy Backend Microservices to AKS

In DevOps Pro, the backend microservices and internal service load balancers are **automatically provisioned and deployed to AKS by Terraform** via `kubernetes.tf` during the `terraform apply` step. There are no manual Helm chart commands required.

#### 6.1 Set Up kubectl Credentials
Once Terraform completes, configure your local environment to access the AKS cluster:

```powershell
# Get your resource group name and project prefix (from repository root)
$rgName = terraform -chdir=terraform output -raw resource_group_name
$projectName = "devopspro" # Replace with your project_name from terraform.tfvars

# Fetch kubeconfig credentials for kubectl
az aks get-credentials --resource-group $rgName --name "${projectName}-aks" --overwrite-existing
```

#### 6.2 Verify the Running Microservices
Once the kubeconfig context is set up, verify that the 7 backend pods are running and healthy inside the AKS cluster:

```powershell
# View all running pods
kubectl get pods

# View services and public IP endpoints of LoadBalancers
kubectl get services
```

The Gateway Service (`gateway-service`) is automatically configured to proxy traffic to internal services, and acts as the entry point for frontend API calls.

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

You can set these secrets using the Azure CLI:
```powershell
# Set the API Client Secret
az keyvault secret set --vault-name "devops-pro-prod-kv" --name "api-client-secret" --value "<YOUR_CLIENT_SECRET>"

# Set the JWT Signing Key
az keyvault secret set --vault-name "devops-pro-prod-kv" --name "jwt-signing-key" --value "<YOUR_JWT_SIGNING_KEY>"
```

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

### 13. Troubleshooting Common Deployment Issues

During deployment to real Azure, you might run into common regional, authorization, or network constraints. Use this section to resolve them.

#### 13.1 Azure Subscription Policy Restrictions (`RequestDisallowedByAzure`)
* **Error**: `RequestDisallowedByAzure: Resource ... was disallowed by Azure: This policy maintains a set of best available regions...`
* **Cause**: Your subscription is restricted to deploying resources in specific allowed regions.
* **Resolution**: Open your `terraform/terraform.tfvars` file and update the `azure_region` variable to match your allowed region (e.g., `azure_region = "centralindia"`).

#### 13.2 Missing Azure Provider Registrations (`MissingSubscriptionRegistration`)
* **Error**: `MissingSubscriptionRegistration: The subscription is not registered to use namespace 'Microsoft.DocumentDB' (or 'Microsoft.KeyVault').`
* **Cause**: Azure requires explicit namespace registration for services before creating them.
* **Resolution**: Register the namespaces using Azure CLI and wait 1-2 minutes:
  ```powershell
  az provider register --namespace Microsoft.DocumentDB
  az provider register --namespace Microsoft.KeyVault
  ```

#### 13.3 vCPU Quota Limits (`ErrCode_InsufficientVCPUQuota`)
* **Error**: `Insufficient regional vcpu quota left... requested quota 4.`
* **Cause**: Your Azure subscription limits the number of vCPUs you can deploy in a region.
* **Resolution**: In `main.tf`, downscale your default node pool to 1 node, disable additional workload pools (set `count = 0`), and consider using memory-optimized VM sizes like `Standard_E2s_v3` (2 vCPUs, 16 GB RAM) to double your memory capacity within the 2 vCPU limit.

#### 13.4 kubelogin Authentication Errors (`exec: executable kubelogin not found`)
* **Error**: `getting credentials: exec: executable kubelogin not found`
* **Cause**: AKS is configured with Azure Active Directory (Entra ID) authentication, which requires installing `kubelogin` locally.
* **Resolution**: Bypass this by fetching the administrator credentials directly (uses cert-based auth, no tools needed):
  ```powershell
  az aks get-credentials --resource-group <resource_group_name> --name <aks_cluster_name> --overwrite-existing --admin
  ```

#### 13.5 Private Cluster Connection Timeouts (`dial tcp ... no such host`)
* **Error**: `dial tcp: lookup devopspro-aks-xxxx: no such host` or connection timeouts.
* **Cause**: AKS was created with `private_cluster_enabled = true` making the API server unreachable from your local network.
* **Resolution**: Change `private_cluster_enabled = false` in `main.tf`. If you are stuck in a catch-22 (refresh fails because cluster is unreachable), run a targeted apply to make the cluster public first:
  ```powershell
  terraform -chdir=terraform apply -var="create_azure_infra=true" -target="azurerm_kubernetes_cluster.aks[0]" -auto-approve
  ```

#### 13.6 Kubernetes Provider Connection Refused (`dial tcp [::1]:80: connectex`)
* **Error**: Provider trying to connect to `localhost:80` and failing during planning/refresh.
* **Cause**: Configuring the `kubernetes` provider dynamically via AKS resource outputs fails during the refresh phase because credentials evaluate to empty.
* **Resolution**: Configure the provider to read directly from your local kubeconfig file in `kubernetes.tf`:
  ```terraform
  provider "kubernetes" {
    config_path = "~/.kube/config"
  }
  ```

#### 13.7 Docker Context Errors during Image Builds (`/config-service/src: not found`)
* **Error**: `failed to calculate checksum: "/config-service/src": not found`
* **Cause**: The multi-module Maven project Dockerfiles contain relative copies and must be built from the repository root.
* **Resolution**: Run the `docker build` command from the **repository root directory** using the root `.` as the build context:
  ```powershell
  docker build -t "${acrLoginServer}/${service}:latest" -f "${service}/Dockerfile" .
  ```

#### 13.8 Terraform State Mismatches and Duplicate Resources (`Unexpected Identity Change`)
* **Error**: `Unexpected Identity Change: During the read operation, the Terraform Provider unexpectedly returned a different identity...` or `Failed to create deployment: deployments.apps "aks-kafka" already exists`.
* **Cause**: When a deployment fails or times out during rollout, the Terraform Kubernetes provider can store a corrupted or incomplete resource identity in its state file. When you try to modify it, the state becomes inconsistent with the actual cluster resources.
* **Resolution**:
  1. Remove the corrupted resource from the Terraform state:
     ```powershell
     terraform -chdir=terraform state rm kubernetes_deployment_v1.kafka[0]
     ```
  2. Manually delete the orphaned conflicting resource from the AKS cluster:
     ```powershell
     kubectl delete deployment aks-kafka
     ```
  3. Re-run the apply command to cleanly re-create the resource:
     ```powershell
     terraform -chdir=terraform apply -var="create_azure_infra=true"
     ```

---

### 14. User Role Management

DevOps Pro uses Role-Based Access Control (RBAC) to enforce security boundaries. Roles govern permissions such as triggering SAST scans, editing configurations, or synchronizing Jira tickets.

#### 14.1 Predefined Roles & Permissions
The system defines 4 default user roles, ordered from highest to lowest privilege:
1. **`ROLE_SYSTEM_ADMIN`**: Full read/write access across all system settings, configurations, and incidents for all tenants.
2. **`ROLE_TENANT_ADMIN`**: Allowed to edit configurations and add repositories for their specific tenant.
3. **`ROLE_SECURITY_ENGINEER`**: Allowed to view and transition security incidents, trigger manual scans, and initiate code auto-fixes.
4. **`ROLE_DEVELOPER_VIEWER`**: Read-only access to view logs, metrics, repository scan summaries, and active incidents.

#### 14.2 Role Mapping: Local Accounts (MongoDB)
For users utilizing standard email/password logins, roles are stored statically in the database:
- **Default Seeding**: Seeded users are configured in `gateway-service` under [`DataSeeder.java`](file:///C:/Users/ahmad/IdeaProjects/devops-pro/gateway-service/src/main/java/com/devops/gateway/config/DataSeeder.java).
- **Modification**: You can modify roles for existing accounts by directly updating the `role` field on user documents in your Cosmos DB MongoDB collection, or by creating a signup registration API flow.

#### 14.3 Role Mapping: Microsoft Entra ID (Azure AD)
When authenticating via Entra ID, the application dynamically resolves the user's role on login based on their email prefix inside `gateway-service`'s [`AuthController.java`](file:///C:/Users/ahmad/IdeaProjects/devops-pro/gateway-service/src/main/java/com/devops/gateway/controller/AuthController.java):
- Emails starting with `sysadmin` ➔ **`ROLE_SYSTEM_ADMIN`**
- Emails starting with `tenantadmin` ➔ **`ROLE_TENANT_ADMIN`**
- Emails starting with `security` ➔ **`ROLE_SECURITY_ENGINEER`**
- Emails starting with `dev` ➔ **`ROLE_DEVELOPER_VIEWER`**
- All other domains/emails ➔ Defaults to **`ROLE_DEVELOPER_VIEWER`**

*To customize these mappings (e.g., using Entra ID AD Groups or App Roles claims), modify the `entraLogin()` method inside `AuthController.java` to extract the roles from the JWT token claims.*

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