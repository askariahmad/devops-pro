# Technical Guide

## Role-Based Access Control (RBAC) Architecture

The application relies on Azure Entra ID (MSAL) for authentication and authorization in production, but seamlessly degrades to a mock provider for local development.

### Mock Provider (Local Dev)
When `SPRING_PROFILES_ACTIVE=dev` is set, the `Gateway Service` intercepts Entra ID login requests on the `/api/v1/auth/entra-login` endpoint. Instead of validating the MSAL token against Azure AD servers, it reads the provided email address and dynamically assigns roles:
- Emails starting with `admin` receive `ROLE_ADMIN`.
- All other emails receive `ROLE_VIEWER`.

The mock provider generates a valid signed JWT containing these roles, which is then passed to all downstream microservices.

### Production Provider
In QA, UAT, and PROD environments, the Gateway Service validates the cryptographic signature of the Entra ID tokens against Azure's public JWKS endpoints. Roles are extracted directly from the App Roles mapped inside the Entra ID tenant.

## LLM AI Routing Architecture

The platform utilizes a dynamic, config-driven routing mechanism for LLM requests (Anomaly Detection and Security Vulnerability explanations).

### Configuration Injection
The `config-service` acts as the source of truth for all LLM routing. The `repo-scanner-service` and `log-analyzer-service` periodically poll the `config-service` to determine the active LLM provider.

### Local LLM (Ollama)
In the `dev` environment, the active LLM provider defaults to `ollama`. 
- Requests are routed to `http://ollama:11434`.
- The `qwen2.5-coder:0.5b` model is used. This is a lightweight (<1GB) coding-specific model that runs purely on CPU, allowing developers to test AI reasoning flows entirely offline without incurring cloud API costs.

### External LLMs
In higher environments, the platform connects to OpenAI or Azure OpenAI using securely injected API keys. The services utilize a Distributed Redis Cache to ensure that multiple identical AI analyses (e.g., encountering the exact same CVE across different microservices) only hit the expensive external LLM APIs once.
