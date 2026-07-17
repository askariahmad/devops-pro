---
name: floci_gcp
description: "Instructions and cheatsheet for using the floci-gcp local GCP emulator for development and CI testing."
---

# Skill: floci-gcp - Local GCP Emulator

## Overview
**floci-gcp** is a fast, free, and open-source local GCP emulator designed for development and CI environments. Unlike official GCP emulators which are often fragmented across different ports and binaries, `floci-gcp` consolidates multiple services onto a single port.

## Capabilities
* **Services:** Storage (GCS, Firestore, Datastore), Messaging (Pub/Sub, Managed Kafka), Compute (Cloud Run, Cloud Functions), and Infrastructure (Secret Manager, IAM, Cloud SQL, Cloud Tasks).
* **No authentication:** Requires no GCP accounts or authentication setups.

## Getting Started
**Option 1: Docker (Recommended)**
```bash
docker run --rm -p 4588:4588 floci/floci-gcp:latest
```
**Option 2: Floci CLI**
`floci gcp start` | `eval $(floci gcp env)` | `floci gcp stop`

## Environment Variables & Configuration
To make standard GCP SDKs and CLI tools interact seamlessly, export the following variables:
```bash
export PUBSUB_EMULATOR_HOST="localhost:4588"
export FIRESTORE_EMULATOR_HOST="localhost:4588"
export DATASTORE_EMULATOR_HOST="localhost:4588"
export STORAGE_EMULATOR_HOST="http://localhost:4588"
export SECRET_MANAGER_EMULATOR_HOST="localhost:4588"
export GOOGLE_CLOUD_PROJECT="floci-local" # Dummy project ID for compatibility
```

## Endpoints
- **Primary Port**: `4588` (handles both REST and gRPC requests).
- **Control Plane**:
  - `/_floci-gcp/health`: Health check endpoint.
  - `/_floci-gcp/info`: Status and info endpoint.

## Best Practices for AI Agents
1. **Single Port:** Always assume `4588` for all services (REST and gRPC).
2. **Setup Automation:** Agents can script `eval $(floci gcp env)` to quickly inject the environment for their session.
3. **Dummy Auth/Project:** Ensure `GOOGLE_CLOUD_PROJECT` is set to `floci-local`.
4. **Health Checks:** Always poll `http://localhost:4588/_floci-gcp/health` to confirm the emulator is running and ready before executing tests.
