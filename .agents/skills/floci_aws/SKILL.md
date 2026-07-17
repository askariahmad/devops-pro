---
name: floci_aws
description: "Instructions and cheatsheet for using the Floci local AWS emulator for development and CI testing."
---

# Skill: Floci AWS Local Cloud Emulator

## Overview
**Floci** (floci.io) is a fast, lightweight, and open-source local cloud emulator that allows developers to run AWS services locally. It boasts millisecond startup times and minimal memory footprint, serving as a seamless, drop-in replacement for LocalStack without accounts or auth tokens.

## Capabilities
* **Drop-in LocalStack Replacement:** Listens on default port `4566`.
* **Services:** Emulates 60+ AWS services (S3, Lambda, SQS, DynamoDB, RDS, API Gateway, etc.).
* **Zero-Friction Authentication:** Accepts any non-empty dummy credentials.

## Installation & Getting Started
Run Floci using Docker:
```bash
docker run -d --name floci -p 4566:4566 floci/floci:latest
```

## Environment Variables & Configuration
To interact with the Floci emulator, set these standard environment variables in the shell:
```bash
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
```

Internal configuration uses the `FLOCI_` prefix (e.g., `FLOCI_SERVICES_CONFIGSERVICE_ENABLED=true`).

## Usage & CLI Interaction
**Using the AWS CLI:**
If `AWS_ENDPOINT_URL` is set globally, `aws` CLI v2 automatically routes commands to Floci.
If not, append the endpoint flag to every command:
```bash
aws s3 ls --endpoint-url http://localhost:4566
```

**Using AWS SDKs (e.g., Python Boto3):**
```python
import boto3
s3_client = boto3.client('s3', endpoint_url='http://localhost:4566', aws_access_key_id='test', aws_secret_access_key='test', region_name='us-east-1')
```

## Best Practices for AI Agents
1. **Assume Port 4566:** Expect Floci AWS services to be running on `http://localhost:4566`.
2. **Dummy Credentials:** Always use `test`/`test` for dummy AWS Access/Secret keys.
3. **Global Endpoint Variable:** Leverage `AWS_ENDPOINT_URL` globally to keep CLI commands clean.
4. **Resource Cleanup:** Stopping and removing the container acts as a fast mechanism to reset the state.
