---
name: backend-architecture
description: Guidelines on the Spring Boot microservices ecosystem.
---
# Backend Architecture
- **Database:** MongoDB driver (connecting to Floci-AZ Cosmos DB or Floci AWS DocumentDB).
- **Messaging:** Kafka protocol (connecting to Floci-AZ Event Hubs or Floci AWS MSK).
- **Auth:** Spring Security OAuth2 Resource Server validating JWTs from Floci endpoints.
