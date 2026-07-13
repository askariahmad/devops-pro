# Development Environment Setup Guide

The `dev` environment is heavily containerized. It mocks massive external systems (like Azure Entra ID) and spins up local versions of Splunk (mocked) and an LLM (Ollama) so you can develop fully offline.

## 1. Local Architecture
- **Docker Compose**: Uses `docker-compose.yml` (Base) + `docker-compose.dev.yml` (Overrides).
- **Ollama**: We run `qwen2.5-coder:1.5b` locally to process LLM requests without cloud API keys.
- **Mock Splunk**: The Log Collector service has a scheduled job that randomly emits mock Splunk security events to Kafka.

## 2. Setting Up External Services (For `realuser`)
We have designed a special hybrid flow. Most users get mock data, but you can log in as `realuser@devops.com` to test your actual external integrations (Jira/Sonar).
1. **Jira Software Cloud**: Go to [Atlassian](https://www.atlassian.com/software/jira/free) and create a free account. Generate an API token from your profile settings.
2. **SonarCloud**: Go to [SonarCloud.io](https://sonarcloud.io/) and link your GitHub account. 

*You will enter these real credentials in the UI after logging in as `realuser@devops.com`.*

## 3. Spin up the Dev Environment
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up --build -d
```

## 4. RBAC Logins
We intercept Entra ID logins locally. Use the mock Single Sign-On (SSO) login flow. Because this simulates an already-authenticated SSO redirect, **the password can be anything** (e.g., `password123`).

**Mock Tenants (Pre-populated with mock vulnerabilities):**
- **System Admin**: `sysadmin@devops.com` (Role: `ROLE_SYSTEM_ADMIN`)
- **Tenant Admin**: `tenantadmin@devops.com` (Role: `ROLE_TENANT_ADMIN`)
- **Security Engineer**: `security@devops.com` (Role: `ROLE_SECURITY_ENGINEER`)
- **Developer**: `dev@devops.com` (Role: `ROLE_DEVELOPER_VIEWER`)

**Real Tenant (Clean database, ready for your real API keys):**
- **Hybrid Real User**: `realuser@devops.com` (Role: `ROLE_SYSTEM_ADMIN`) 
  *(This user still receives the random mock Splunk logs for testing the log-analyzer, but repository scans will hit your real GitHub/Sonar endpoints).*
