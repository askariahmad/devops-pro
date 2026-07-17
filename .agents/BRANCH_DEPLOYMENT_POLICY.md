# Branch & Deployment Policy (AWS / Azure)

Purpose: keep a single, canonical policy in the repo so all contributors and agents know how to work on cloud-specific branches, run locally with Floci, and prepare artifacts so they are easily deployable to production later.

Summary (one-liner):
- Work happens on cloud-specific feature branches (`feat/aws-*`, `feat/azure-*`) or short-lived feature branches that target those branches; local testing uses Floci emulators; production-ready artifacts must still be compatible with real cloud providers.

Checklist (what this policy enforces):
- All changes that affect cloud infra, Terraform, or cloud-specific deployment manifests MUST be committed to the matching branch:
  - AWS work → branch `feat/aws-migration` (or `aws-feature/*` for smaller changes)
  - Azure work → branch `feat/azure-migration` (or `azure-feature/*`)
- Developers create feature branches from the appropriate cloud branch and open PRs that target that cloud branch.
- Local developer flow must use Floci emulator (`floci/floci:latest` for AWS, `floci/floci-az:latest` for Azure) for testing; CI must also support an emulator stage until real cloud credentials are added.
- Scrum Master enforces PR merge gates per `.agents/CODE_REVIEW_POLICY.md` and will only merge PRs into the cloud branch once reviewers and checks pass.
- Each microservice (submodule) must maintain separate cloud-branch feature branches if changes are required in their repo.

Details & Rationale

1) Branch naming and intent
- Long-lived integration branches that represent cloud migration efforts:
  - `feat/aws-migration` – the branch that contains the canonical Terraform + Kubernetes manifests tuned for AWS (EKS/ECR/ElastiCache/MSK/DocDB, etc.)
  - `feat/azure-migration` – the branch that contains the canonical Terraform + Kubernetes manifests tuned for Azure (AKS/ACR/Azure Cache/Entra, etc.)
- Short-lived feature branches must be named using a cloud prefix and TASK-ID, for example:
  - `aws-feature/TASK-001/add-msk-docdb-terraform`
  - `azure-feature/TASK-010/fix-aks-image-reference`

2) Where changes must go
- If the change modifies Terraform files, `kubernetes.tf`, cloud provider configs (provider blocks), or deployment manifests that are specific to AWS or Azure, the change must target the respective cloud branch.
- If the change is cloud-agnostic (pure business logic, unit tests, API changes, docs), it can be made on the mainline branch or appropriate service repo branch, but the Scrum Master must ensure the cloud branches receive backports as required.
- Because this repo uses Git submodules (services as separate repos), the corresponding service repository must also receive feature branches for cloud-specific changes. The PR to the top-level repo should reference the matching PR(s) in the submodule repos.

3) Local development with Floci (emulator)
- AWS local emulator (Floci/LocalStack):
  - Start:

```powershell
# Windows cmd/powershell example
# AWS Floci
docker rm -f floci-aws 2> nul || rem
docker run -d -p 4566:4566 --name floci-aws floci/floci:latest
# Run deploy script for aws
powershell -File .\deploy.ps1 -Cloud aws
```

- Azure local emulator (Floci-AZ):

```powershell
# Azure Floci
docker rm -f floci-az 2> nul || rem
docker run -d -p 4577:4577 --name floci-az floci/floci-az:latest
# Run deploy script for azure
powershell -File .\deploy.ps1 -Cloud azure
```

- Notes:
  - The Floci emulator endpoints (4566 for AWS, 4577 for AZ) are already referenced in the Terraform configurations for local development. Keep `access_key = "test"` and `skip_credentials_validation = true` in provider blocks only for local/test usage — do NOT commit production credentials.
  - CI jobs that run integration tests should either: start the Floci emulator in a job stage, or use provider mocks that match the emulator endpoints. This preserves parity between local and CI.

4) PR targeting rules (required)
- Always create PRs that target the cloud branch relevant to your change (`feat/aws-migration` or `feat/azure-migration`).
- PR title must include `TASK-{ID}` when the change originates from the Scrum board (e.g., `TASK-001: Add MSK and DocDB terraform`)
- PR description must reference the acceptance criteria, local steps to test with Floci, and the related submodule/service PRs (if any).

5) Backports and synchronization
- When a change is made in `feat/aws-migration` that is relevant to `feat/azure-migration` (or vice versa) it should be considered for backporting or dual implementation. The Scrum Master will create tasks for synchronization and coordinate agents to apply equivalent changes in the other branch/repo.

6) Production readiness steps (keep repo ready for production)
- Keep Terraform code modular and parameterized (use variables.tf) so switching provider endpoints / secrets is a minimal change.
- Secrets MUST be externalized (Terraform secret resource, cloud secret store, or Kubernetes Secret managed by Terraform) — never commit production secrets.
- CI/CD pipeline templates should be present and parameterized per cloud provider; until the pipeline is run against real clouds, test against Floci emulators.
- Ensure `authConfig.js` and other environment-specific files support build-time or runtime injection of production values.

7) Enforcement & automation
- The Scrum Master (agent) enforces branch targeting and PR merge gates. Agents must include in PR description: target branch, affected services, Floci test steps.
- Optional automation (future): add branch protection rules in the hosting Git provider (GitHub/GitLab/Azure DevOps) to require PRs for the `feat/aws-migration` and `feat/azure-migration` branches and require required reviewers.

Quick Git workflow examples (Windows cmd)

```bat
:: Create a feature branch from the correct cloud branch
git fetch origin
git checkout origin/feat/aws-migration -b aws-feature/TASK-001/add-msk-docdb-terraform
:: Make changes, commit
git add .
git commit -m "feat(TASK-001): add MSK and DocDB terraform resources"
:: Push to remote
git push origin HEAD
:: Create PR on your Git hosting service targeting feat/aws-migration
```

What I implemented now
- This single file documents the branch targeting rules, local Floci usage, PR rules, and production-readiness guidance.
- Reference the existing `.agents/CODE_REVIEW_POLICY.md` and `.agents/SCRUM_MASTER_GUIDE.md` for enforcement and PR merge governance.

Next recommended steps (I can do these for you):
- Add branch protection rules in the Git host (I can generate suggested rules or GitHub Actions to enforce PR targets)
- Update CI templates to include a Floci stage for emulator-based integration tests
- Add a small script that validates a PR targets the correct cloud branch (pre-merge hook or CI check)

If you want, I will now:
- (A) create a lightweight CI check script and example GitHub Actions workflow that starts Floci and runs Terraform plan/apply in dry-run mode, or
- (B) add branch protection suggestion file for your Git hosting provider.

Which next step should I take? (A/B/none)
