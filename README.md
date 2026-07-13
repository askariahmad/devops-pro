# DevSecOps Pro

DevSecOps Pro is an enterprise-grade, event-driven microservices platform designed to orchestrate and automate security scanning, log analysis, and incident management across a multi-environment architecture.

## Overview
The platform seamlessly integrates with external systems like Jira, SonarQube, GitHub, and Splunk to provide a centralized pane of glass for security operations. It leverages LLMs (both local and cloud-based) to analyze vulnerabilities and logs, generating automated remediation steps.

## High-Level Design (HLD)

```mermaid
graph TD
    subgraph Frontend
        UI[Dashboard UI React]
    end

    subgraph API Layer
        GW[Gateway Service Auth/Routing]
    end

    subgraph Core Services
        INC[Incident Service]
        SCN[Repo Scanner Service]
        LAN[Log Analyzer Service]
        LCL[Log Collector Service]
        CFG[Config Service]
        NOT[Notification Service]
    end

    subgraph Infrastructure
        KAF[Kafka Event Bus]
        MONGO[(MongoDB)]
        REDIS[(Redis Cache)]
    end

    subgraph External Integrations
        JIRA[Jira Cloud]
        SONAR[SonarQube]
        GITHUB[GitHub]
        SPLUNK[Splunk]
        LLM[Ollama / OpenAI]
        ENTRA[Azure Entra ID]
    end

    UI --> GW
    GW --> INC
    GW --> CFG
    GW -.-> ENTRA

    LCL --> KAF
    SCN --> KAF
    LAN --> KAF
    KAF --> INC
    KAF --> NOT

    SCN --> SONAR
    SCN --> GITHUB
    SCN --> LLM
    LAN --> LLM
    LCL --> SPLUNK
    INC --> JIRA

    CFG --> MONGO
    INC --> MONGO
```

## Features
- **Multi-Tenant Architecture**: Robust data isolation across multiple tenants.
- **RBAC**: Deep integration with Azure Entra ID (mocked in DEV).
- **Event-Driven**: Fully decoupled asynchronous processing via Apache Kafka.
- **LLM Integration**: Langchain4j integration supporting local (Ollama) and cloud (OpenAI/Azure) models.

## Setup Guides
Please select the appropriate setup guide for your target environment:
- [Development Environment Setup](./guides/SETUP_GUIDE_DEV.md)
- [QA & UAT Environment Setup](./guides/SETUP_GUIDE_QA_UAT.md)
- [Production Environment Setup](./guides/SETUP_GUIDE_PROD.md)
- [Technical Guide & Architecture Details](./guides/TECHNICAL_GUIDE.md)
