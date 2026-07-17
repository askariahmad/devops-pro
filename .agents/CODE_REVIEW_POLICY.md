# Code Review & PR Workflow Policy

## Overview
All code changes must go through a structured PR review process. Direct merges are prohibited. This ensures code quality, security, and architectural consistency.

## Branch Strategy

### Long-Lived Cloud Branches
Maintain two long-lived branches for the cloud workstreams:
- **Azure**: `feat/azure-migration`
- **AWS**: `feat/aws-migration`

Azure is the initial focus. Every Azure implementation must be documented clearly so the same workflow can be reproduced later for AWS with minimal rework.

### Branch Naming Convention
```
{cloud}-{feature|bugfix|hotfix}/{ticket-id}/{description}
```

Examples:
- `aws-feature/TASK-001/payment-gateway-integration`
- `azure-bugfix/TASK-042/auth-token-expiry`
- `gcp-hotfix/TASK-089/database-connection-pool`

### Working Branch Rules
- Each agent starting work must create its own feature branch from the relevant long-lived cloud branch.
- Azure work branches should start from `feat/azure-migration`.
- AWS work branches should start from `feat/aws-migration`.
- Work must stay in the feature branch until review and approval are complete.

## PR Workflow

### Step 1: Developer Creates Feature Branch
```
git checkout feat/azure-migration
git pull origin feat/azure-migration
git checkout -b azure-feature/TASK-001/my-feature
# Make changes
git commit -m "feat: add new feature (TASK-001)"
git push origin azure-feature/TASK-001/my-feature
```

### Step 2: Developer Creates Pull Request
- Must include ticket ID (e.g., TASK-001)
- Must reference acceptance criteria
- Must include test coverage info
- Must include documentation updates that explain the Azure change and its reusability for AWS

**PR Template:**
```markdown
## Task ID
TASK-001

## Description
What does this PR do?

## Acceptance Criteria Met
- [ ] Criterion 1
- [ ] Criterion 2

## Changes
- List of changes

## Testing
- How was this tested?
- Test coverage: X%

## Documentation
- [ ] README updated
- [ ] API docs updated
- [ ] Architecture guide updated

## Screenshots/Logs (if applicable)
```

### Step 3: Required Reviewers by Domain

#### Backend Changes (`backend-developer`)
- **Mandatory**: @architect, @security-auditor
- **Requested**: @database-engineer (if DB changes), @devops-engineer (if infra)

#### Frontend Changes (`frontend-developer`)
- **Mandatory**: @architect, @ui-designer
- **Requested**: @tester (if complex logic), @documentation-engineer (if UI docs)

#### Infrastructure/DevOps (`devops-engineer`)
- **Mandatory**: @architect, @security-auditor
- **Requested**: @database-engineer (if persistence layer), @backend-developer (if service config)

#### Database Changes (`database-engineer`)
- **Mandatory**: @architect, @security-auditor
- **Requested**: @backend-developer, @devops-engineer (if migrations)

#### Documentation (`documentation-engineer`)
- **Mandatory**: @architect, @product-manager
- **Requested**: @backend-developer (if technical accuracy needed)

### Step 4: Code Review Checklist

Reviewers must verify:

#### Code Quality
- [ ] Code follows project standards
- [ ] No code smells or anti-patterns
- [ ] Proper error handling
- [ ] Logging is adequate
- [ ] No hardcoded values/secrets

#### Functionality
- [ ] Implements all acceptance criteria
- [ ] No regression in existing features
- [ ] Edge cases handled
- [ ] Performance acceptable

#### Security
- [ ] No security vulnerabilities
- [ ] Input validation present
- [ ] Authentication/authorization correct
- [ ] No exposed credentials/tokens
- [ ] OWASP compliance (for web)

#### Testing
- [ ] Unit tests included
- [ ] Integration tests pass
- [ ] Test coverage acceptable (>80% for new code)
- [ ] No flaky tests

#### Documentation
- [ ] Code is well-commented
- [ ] README updated if applicable
- [ ] API documentation updated (for APIs)
- [ ] Architecture guide updated (if design changes)

### Step 5: Approval & Merge

**Merge Rules:**
- ✅ All mandatory reviewers must approve
- ✅ At least 2 approvals required
- ✅ All CI/CD checks must pass
- ✅ Branch must be up-to-date with the target cloud branch
- ✅ No merge conflicts
- ✅ Azure changes must include documentation that can later be mirrored to AWS

**Who can merge:**
- @scrum-master (after PR approved)
- @architect (architecture decisions)
- @devops-engineer (infrastructure only)
- NO developers can directly merge

### Step 6: Merge to Cloud Branch
```
git checkout feat/azure-migration
git pull origin feat/azure-migration
git merge --no-ff azure-feature/TASK-001/my-feature
git push origin feat/azure-migration
```

## Handling Review Feedback

**Developer Responsibilities:**
1. Address all comments from reviewers
2. Commit feedback changes: `git commit -m "chore: address review comments"`
3. Push updates: `git push origin aws-feature/TASK-001/my-feature`
4. Re-request review from reviewers
5. Do NOT force-push (unless approved by lead)

**Reviewer Responsibilities:**
1. Provide constructive feedback
2. Re-review changes promptly
3. Approve once satisfied or request changes again
4. Resolve conversations as cleared

## Blocked PRs

If a PR is blocked:
- Add comment explaining reason
- Add to blocker list in task file (TASK-{ID}.json)
- Notify Scrum Master via run_subagent
- Example: "Blocked on TASK-002 (database migration)"

## PR Status Tracking

The Scrum Master should track:
- PRs awaiting review (tag: `needs-review`)
- PRs awaiting author feedback (tag: `changes-requested`)
- PRs approved but pending merge (tag: `approved`)
- PRs merged (tag: `merged`)

## Escalation

If PR conflicts arise:
1. Developer + Reviewers discuss in PR comments
2. If unresolved → Scrum Master mediates
3. If architectural → Escalate to @architect
4. If security → Escalate to @security-auditor
5. Final decision → @manager

## Metrics to Track

- Average time from PR creation to merge
- Number of review cycles per PR
- Types of issues caught in review
- Developer adherence to code standards

---
**Remember**: Code reviews catch bugs early, share knowledge, and maintain architectural integrity! 🔍✅

