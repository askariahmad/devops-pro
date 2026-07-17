---
name: floci_az
description: "Instructions and cheatsheet for using the Floci-AZ local Azure emulator for development and CI testing."
---

# Skill: Floci-AZ (Azure Local Cloud Emulator)

## Overview
**Floci-AZ** is a fast, free, open-source local Azure emulator built using Quarkus Native. It allows developers and AI agents to emulate Azure-compatible services locally without needing an Azure subscription or authentication tokens.

## Capabilities
* **Unified Port:** Emulates multiple Azure services through a single port (`4577` by default).
* **Wire-Compatible:** Works seamlessly with existing Azure SDKs, Terraform, and Azurite tools.
* **Services:** Storage (Blob, Queue, Table), Compute (Functions, AKS, VMs), Messaging (Event Hubs, Service Bus), DBs (Cosmos DB, Azure SQL), etc.

## Installation & Quick Start
Via Docker (Ports `5672`/`5673` optional for AMQP):
```bash
docker run --rm -p 4577:4577 -p 5672:5672 -p 5673:5673 floci/floci-az:latest
```
Via Floci CLI: `floci az start`

## Endpoints & Connection Configuration
By default, Floci-AZ runs all REST APIs on `http://localhost:4577`.
Floci-AZ settings use `FLOCI_AZ_` prefixed environment variables (e.g. `FLOCI_AZ_PORT`, `FLOCI_AZ_TLS_ENABLED`).

For automated local development, inject Floci environment variables into the shell using:
```bash
eval $(floci az env)
```
This automatically sets standard Azure environment variables (e.g., `AZURE_STORAGE_CONNECTION_STRING`) to point to the local instance.

## `azfloci` Companion CLI
`azfloci` is a transparent proxy wrapper for the official Azure CLI (`az`). It intercepts `az` commands, bypasses SSL verification, and forces the CLI to talk to the local Floci-AZ instance.
```bash
azfloci storage account list
```

## Best Practices for AI Agents
1. **Always Use Standard SDKs:** Do not hardcode `localhost` directly into application logic.
2. **Inject Connection Strings via Env Vars:** Pass the emulator's endpoint `http://localhost:4577` via configuration files or environment variables.
3. **Use the Companion Tool for Provisioning:** Use `azfloci` instead of `az` for CLI operations.
4. **Disable SSL Locally:** Ensure connection strings explicitly specify that HTTPS is not required for the emulator.
