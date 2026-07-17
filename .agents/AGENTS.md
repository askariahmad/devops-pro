# DevOps-Pro Project Rules

## Architecture Standards
- **Backend:** Spring Boot Microservices, Java 17+. No Lombok annotations (use manual getters/setters).
- **Frontend:** React + Vite.
- **Styling:** Use Vanilla CSS. Strictly enforce rich aesthetics, dark modes, glassmorphism, or dynamic animations. No basic designs.
- **Infrastructure:** All compute and resources are orchestrated via Terraform (in the terraform/ folder).
- **Cloud Testing:** All deployments target local floci (AWS) or floci-az (Azure) emulators. No raw docker-compose.yml files for production dependencies.

## Communication & Git
- Ensure all commits follow conventional commit messages (e.g., feat:, fix:, chore:).
- Keep walkthrough artifacts continuously updated with architectural choices.

## Local Emulator & Kubernetes Rules
- **Emulator Permissions:** Start local emulators as root (`-u 0`) to resolve Docker socket permissions on Windows.
- **AKS/K3s Emulation:** Always set `FLOCI_AZ_SERVICES_AKS_MOCKED=true` locally to bypass K3s sub-container API hangs.
- **Local K8s Routing:** Fallback the `kubernetes` provider to `~/.kube/config` locally, routing databases/caches to `host.docker.internal` instead of `localhost`.
- **Bypass Unsupported APIs:** Conditionally count-bypass (`create_cosmos_and_keyvault`) Cosmos DB, Key Vault, Redis caches, and Azure Role Assignments locally to avoid 404/OOM/exec errors.
- **PowerShell Tagging:** Always wrap PowerShell loop variables in `${var}` (e.g., `${service}:latest`) to avoid namespace scope collision.

## Lessons Learned
- **DevOps Runbooks & Troubleshooting**: Always refer to the custom skill [lessons-learned](file:///c:/Users/ahmad/IdeaProjects/devops-pro/.agents/skills/lessons-learned/SKILL.md) for local cluster verification, LoadBalancer allocation/deletion hang mitigations, MSAL authority protocols, PowerShell Native command stderr crash handling, and API server pacing.


