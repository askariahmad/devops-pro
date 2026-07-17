---
name: azure_entra_id
description: "Instructions, best practices, and troubleshooting for Microsoft Entra ID (Azure AD) in the DevOps Pro project."
---

# Skill: Microsoft Entra ID (Azure AD)

## Overview
Microsoft Entra ID (formerly Azure AD) is a cloud identity and access management service used in the DevOps Pro project for single sign-on (SSO) and authentication.

## Capabilities
- **Single Sign-On (SSO)**: Allow users to log in with their Microsoft work/school accounts or personal accounts.
- **App Registrations**: Register applications to integrate with Entra ID for authentication.
- **Roles and Permissions**: Manage access to Azure resources with RBAC (Role-Based Access Control).
- **Managed Identities**: Eliminate the need for credentials in code by using managed identities for Azure resources.

## App Registrations in DevOps Pro
The project uses two app registrations:
1. **UI App (SPA)**:
   - Name: `devops-pro-ui`
   - Type: Single-page application (SPA)
   - Redirect URI: `https://devops-pro-ui.azurestaticapps.net/auth/callback`
   - Permissions: `User.Read` and `api://devops-pro-api/api.read`
2. **API App**:
   - Name: `devops-pro-api`
   - Type: Web application
   - Exposed API: Scope `api.read`
   - Client Secret: Created for backend authentication

## Quick Start (Portal)
1. **Create UI App Registration**:
   - Go to Entra ID → App registrations → New registration
   - Name: `devops-pro-ui`
   - Supported account types: Choose based on your needs (single-tenant, multi-tenant)
   - Redirect URI: SPA → `https://devops-pro-ui.azurestaticapps.net/auth/callback`
   - Register
2. **Create API App Registration**:
   - New registration → Name: `devops-pro-api`
   - Supported account types: Same as UI app
   - Redirect URI: Web → `https://devops-pro-ui.azurestaticapps.net/swagger-ui/oauth2-redirect.html`
   - Register
3. **Expose API for API App**:
   - Open API app → Expose an API → Set application ID URI → Add scope `api.read`
4. **Add API Permissions to UI App**:
   - Open UI app → API permissions → Add a permission → My APIs → devops-pro-api → Delegated permissions → `api.read` → Grant admin consent

## Quick Start (CLI)
```bash
# Create UI app
az ad app create --display-name "devops-pro-ui" --sign-in-audience AzureADMyOrg --is-spa true --web-redirect-uris "https://devops-pro-ui.azurestaticapps.net/auth/callback"

# Create API app
az ad app create --display-name "devops-pro-api" --sign-in-audience AzureADMyOrg --web-redirect-uris "https://devops-pro-ui.azurestaticapps.net/swagger-ui/oauth2-redirect.html"

# Create API client secret
az ad app credential reset --id <api-client-id> --append --credential-description "devops-pro-api-secret" --years 2
```

## MSAL Configuration (Frontend)
The frontend uses `@azure/msal-browser` and `@azure/msal-react` (see `dashboard-ui/src/authConfig.js`):
```js
export const msalConfig = {
  auth: {
    clientId: "YOUR_UI_CLIENT_ID",
    authority: "https://login.microsoftonline.com/YOUR_TENANT_ID",
    redirectUri: window.location.origin,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  }
};
```

## Best Practices for DevOps Pro
1. **Validate Tokens**: Always validate Entra ID tokens in the backend using Microsoft's JWKS endpoint.
2. **Use Managed Identities**: For backend services accessing other Azure resources, use managed identities instead of client secrets.
3. **Limit Permissions**: Follow the principle of least privilege—only grant the permissions your app needs.
4. **Rotate Secrets**: Regularly rotate client secrets (and use managed identities if possible to avoid secrets altogether).

## Troubleshooting
- **"Invalid grant" error**: Make sure you're using the correct client ID, tenant ID, and redirect URI.
- **API not showing in "My APIs"**: Verify both apps are in the same Entra ID tenant and you're signed in with the correct account.
- **Consent required**: Users from other tenants may need admin consent before they can use your multi-tenant app.

## Local Development
For local development, use the Entra ID app registrations (create a separate one for local) with a redirect URI of `http://localhost:3000/auth/callback` (or whatever your local dev server uses).
