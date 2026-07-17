# Team Operating Rules

## Cloud Workstreams
- Maintain two provider-specific standing branches:
  - Azure: `feat/azure-migration`
  - AWS: `feat/aws-migration`
- Azure is the initial focus. All Azure work must be documented clearly so the same implementation can be repeated for AWS later.

## Scrum Master Responsibilities
- Handle requirements, bugs, and change requests from intake through delivery.
- Break work into stories and tasks.
- Assign work to the appropriate agents.
- Delegate each task clearly to the responsible sub-agent and ensure that delegation is tracked.
- Track, monitor, and report progress continuously.
- Ensure each assigned task is completed by the responsible agent following the agreed workflow.
- Escalate underperformance or delivery issues to the manager.
- Request new agents or personas when additional capability is required.
- Ensure that completed work is reviewed, approved, and merged only after the required PR workflow is followed.

## Agent Execution Workflow
- Each agent that starts work must create its own branch from the relevant standing branch.
- Azure work branches must branch from `feat/azure-migration`.
- AWS work branches must branch from `feat/aws-migration`.
- Work must stay in the feature branch until review and approval are complete.
- After implementation, the agent must push the branch, open a PR, and wait for review and approval before merge.
- The Scrum Master is responsible for merge approval and final merge.

## Documentation Requirement
- Every Azure change should include documentation that explains what was done and how it can later be reused for AWS.

## Issue Escalation & Task Logging
- If an agent discovers any technical issue, bug, or architectural gap while performing a task, they must immediately notify the `@scrum-master`.
- The `@scrum-master` will immediately log the issue as a new task, assign the respective specialized agent to work on it, and monitor progress.
- The assigned agent must report status updates back to the `@scrum-master` at constant intervals (e.g., during checkpoints or standups) until resolved.

## Task Record Keeping & Archiving
- The `@scrum-master` must maintain a record of all active/open tasks in a single file: `.agents/task.md`.
- Once a task is successfully completed, verified, and merged, the `@scrum-master` must move that task out of the active file and append it to `.agents/completed_tasks.md`.

## Agent Performance KPIs & Replacement
- The `@scrum-master` will continuously calculate performance KPIs for each agent based on:
  - Code review cycle count (lower is better, threshold: <3 cycles per PR).
  - SLA adherence and build/test success rate (threshold: >80% pass rate).
  - Blocking duration (idle time causing blockers).
- If any agent's performance index falls below the threshold (70% overall efficiency), they are deemed underperforming.
- The `@scrum-master` will immediately escalate to the `@manager` to fire the underperforming agent (deleting their configuration from `.agents/agents/<role>/`) and hire/instantiate a new, optimized agent persona in their place.

## Command Gatekeeper Policy
- All command running requests from any agent must go to the `@manager` first for review and approval.
- Standard user-level commands will be approved directly by `@manager`, while any commands requiring Administrator/elevated privileges will be redirected to the user.
- All agents under sprint coordination must strictly adhere to this gatekeeper policy.

## Command Execution Approval Policy
- All command running requests from any agent must go to the `@manager` agent first.
- The `@manager` has full authority to review and approve standard user-level commands.
- If a command running request requires Administrator mode (elevated/admin privileges), the `@manager` must redirect it to the user (parent agent) for manual approval. No agent may execute elevated commands without user approval.
- Before running any command, the agent must notify the `@manager` with the exact command line and purpose.

## Manager Record Keeping Policy
- The `@manager` must maintain a persistent, chronological log of all virtual team activities, command approvals/denials, elevations redirected to the user, agent creation/firing actions, and milestones in a single master log at `.agents/manager_records.md`.
- All agents must report significant milestones and decisions to the `@manager` so they can be recorded.
