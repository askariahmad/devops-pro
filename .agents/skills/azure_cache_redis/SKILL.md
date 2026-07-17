---
name: azure_cache_redis
description: "Instructions, best practices, and troubleshooting for Azure Cache for Redis in the DevOps Pro project."
---

# Skill: Azure Cache for Redis

## Overview
Azure Cache for Redis is a fully managed, in-memory cache service provided by Microsoft Azure, used in the DevOps Pro project for LLM result caching and session data storage.

## Capabilities
- **High Performance**: In-memory data store for low-latency access.
- **High Availability**: Built-in replication and failover.
- **Security**: TLS 1.2+ only, VNet integration, Azure AD authentication.
- **Scaling**: Scale up/down or scale out (clustering).

## Deployment in DevOps Pro
The Azure Cache for Redis instance is provisioned via Terraform in `terraform/main.tf`:
- **Resource Group**: `devops-pro-rg`
- **Cache Name**: `devops-redis-cache`
- **SKU**: Standard C1 (1 GB cache)
- **Non-SSL Port**: Disabled (TLS 1.2+ required)
- **Minimum TLS Version**: 1.2

## Key Terraform Configuration
```hcl
resource "azurerm_redis_cache" "redis" {
  count                 = var.create_cosmos_and_keyvault ? 1 : 0
  name                  = "devops-redis-cache"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  capacity              = 1
  family                = "C"
  sku_name              = "Standard"
  enable_non_ssl_port   = false
  minimum_tls_version   = "1.2"
}
```

## Quick Start (CLI)
1. **Get Connection String**:
   ```bash
   az redis list-keys --name devops-redis-cache --resource-group devops-pro-rg
   ```
2. **Connect with redis-cli (from Azure Cloud Shell or local redis-cli):
   ```bash
   redis-cli -h devops-redis-cache.redis.cache.windows.net -p 6380 -a <your-primary-key
   ```

## Best Practices for DevOps Pro
1. **Use TLS Only**: Always use SSL (port 6380) instead of non-SSL (port 6379) for security.
2. **Set Expiry for Keys**: Use TTL (time-to-live) for cached data to avoid filling up the cache.
3. **Use Connection Pools**: In your Spring Boot apps, use a connection pool for Redis to avoid connection limits.
4. **Monitor Metrics**: Use Azure Monitor to track cache hit/miss ratios, memory usage, and latency.
5. **Scale as Needed**: Start with Standard C1 for dev, scale up to C2+ for production with more traffic.

## Troubleshooting
- **Connection Issues**: Make sure your client supports TLS version is 1.2+, and you're using port 6380.
- **High Latency**: Check if the cache is in the same region as your AKS cluster.
- **Cache Misses**: Check your TTL settings and ensure you're caching the right data.
- **Memory Pressure**: If memory usage is high, scale up the cache size or delete unused keys.

## Local Development with Floci-AZ
For local development, use the Floci-AZ emulator (see `floci_az` skill) to simulate Redis without real Azure costs. If you don't want to use Floci-AZ, you can also run a local Redis container:
```bash
docker run -d -p 6379:6379 redis:alpine
```
