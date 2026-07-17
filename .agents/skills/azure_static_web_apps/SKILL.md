---
name: azure_static_web_apps
description: "Instructions, best practices, and troubleshooting for Azure Static Web Apps in the DevOps Pro project."
---

# Skill: Azure Static Web Apps

## Overview
Azure Static Web Apps is a fully managed service for deploying static web applications (like React, Vue, Angular) with optional serverless APIs, used in the DevOps Pro project to host the frontend dashboard.

## Capabilities
- **Global Distribution**: Automatically distributes your app to Azure's global CDN for low latency.
- **CI/CD Integration**: Built-in CI/CD pipelines from GitHub or Azure DevOps.
- **Custom Domains & TLS**: Free SSL certificates and support for custom domains.
- **Authentication**: Built-in support for Entra ID, GitHub, Google, and more.
- **Serverless APIs**: Option to add serverless APIs with Azure Functions.

## Deployment in DevOps Pro
The Static Web App is deployed manually or via CI/CD, pointing to the `dashboard-ui` directory in the repo:
- **App Name**: `devops-pro-ui`
- **Resource Group**: `devops-pro-rg`
- **SKU**: Standard (supports custom domains and more features)
- **App Location**: `/dashboard-ui`
- **Output Location**: `/dist` (where Vite builds the app)

## Quick Start (CLI)
1. **Create a Static Web App**:
   ```bash
   az staticwebapp create \
       --name devops-pro-ui \
       --resource-group devops-pro-rg \
       --location eastus \
       --sku Standard \
       --source https://github.com/your-username/your-repo.git \
       --branch main \
       --app-location dashboard-ui \
       --output-location dist \
       --login-with-github
   ```
2. **Add Environment Variables**:
   Go to the Azure Portal → Static Web App → Configuration → Add the following:
   - `REACT_APP_CLIENT_ID`: Your Entra ID UI app client ID
   - `REACT_APP_TENANT_ID`: Your Entra ID tenant ID
   - `REACT_APP_AUTHORITY`: `https://login.microsoftonline.com/YOUR_TENANT_ID`
   - `REACT_APP_REDIRECT_URI`: `https://devops-pro-ui.azurestaticapps.net/auth/callback`

## Quick Start (Portal)
1. Go to Azure Portal → Search for "Static Web Apps" → Create
2. Fill in the details (resource group, name, SKU)
3. For deployment details, select your GitHub repo, branch, and app/output locations
4. Review and create
5. After deployment, add environment variables via the Configuration blade

## Best Practices for DevOps Pro
1. **Use Staging Environments**: Use staging slots to test changes before deploying to production.
2. **Custom Domain**: Add a custom domain (e.g., `app.devopspro.com`) instead of using the default `azurestaticapps.net` domain.
3. **Enable Authentication**: Use the built-in authentication for Static Web Apps if you don't need custom SSO (though the project uses MSAL for custom SSO).
4. **Monitor Traffic**: Use Azure Monitor to track requests, errors, and performance.
5. **CI/CD Pipeline**: Use the built-in GitHub Actions workflow or Azure DevOps pipeline for automatic deployments on every commit.

## Troubleshooting
- **Build Errors**: Check the GitHub Actions (or Azure DevOps) logs for build errors. Make sure you're using the correct app and output locations.
- **Environment Variables Not Working**: Verify that you added the variables in the Static Web App's Configuration blade and saved them.
- **Route Issues**: For SPA apps (like React), Static Web Apps automatically handles client-side routing—make sure you're not getting 404s on deep links.
- **Performance**: Check if your static assets (images, CSS, JS) are being cached properly by the CDN.

## Local Development
For local development, use Vite's dev server:
```bash
cd dashboard-ui
npm install
npm run dev
```
Then visit `http://localhost:3000`.
