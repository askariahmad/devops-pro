# Script to add description fields to all request YAML files
# Uses string insertion to add description after the name: line

$descriptions = @{
  'Auth/Login.request.yaml' = @"
description: |-
  Authenticates a user with username/email and password. Returns a JWT token on success.

  **Required body fields:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``username`` | string | Username or email address |
  | ``password`` | string | User password |

  **Responses:**
  - ``200 OK`` — ``{ "token": "<jwt>" }``
  - ``401 Unauthorized`` — Invalid credentials
"@

  'Auth/Signup.request.yaml' = @"
description: |-
  Registers a new user account. Auto-provisions a tenant ID based on the email domain. Returns a JWT token on success.

  **Required body fields:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``email`` | string | User email (also used as username) |
  | ``firstName`` | string | First name |
  | ``lastName`` | string | Last name |
  | ``password`` | string | Password |

  **Responses:**
  - ``200 OK`` — ``{ "token": "<jwt>" }``
  - ``409 Conflict`` — Email already registered
"@

  'Auth/Entra-Login.request.yaml' = @"
description: |-
  Authenticates via Microsoft Entra ID (Azure AD / MSAL). Accepts an Entra token and the user's email, and returns a DevOps Pro JWT. Role is assigned based on email prefix:

  | Email prefix | Role |
  |---|---|
  | ``sysadmin*`` | ``ROLE_SYSTEM_ADMIN`` |
  | ``tenantadmin*`` | ``ROLE_TENANT_ADMIN`` |
  | ``security*`` | ``ROLE_SECURITY_ENGINEER`` |
  | ``dev*`` | ``ROLE_DEVELOPER_VIEWER`` |

  **Required body fields:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``entraToken`` | string | MSAL-issued Entra token |
  | ``username`` | string | User email from MSAL |

  **Responses:**
  - ``200 OK`` — ``{ "token": "<jwt>" }``
  - ``400 Bad Request`` — Missing username
"@

  'Config-Service/Get-Config.request.yaml' = @"
description: |-
  Retrieves the system configuration for the authenticated tenant. Returns an empty config object if none has been saved yet.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier (injected by gateway from JWT) |

  **Responses:**
  - ``200 OK`` — ``SystemConfig`` object
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Config-Service/Save-Config.request.yaml' = @"
description: |-
  Creates or updates the system configuration for the authenticated tenant. Supports integration settings for Jira, SonarCloud, Splunk, GitHub, and LLM providers.

  When new GitHub repositories are added and SonarCloud is configured, projects are auto-provisioned in SonarCloud.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body schema (``SystemConfig``):**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``jiraUrl`` | string | Jira instance URL |
  | ``jiraEmail`` | string | Jira account email |
  | ``jiraToken`` | string | Jira API token |
  | ``jiraProjectKey`` | string | Jira project key (e.g. ``DEV``) |
  | ``sonarUrl`` | string | SonarCloud/SonarQube URL |
  | ``sonarToken`` | string | SonarCloud token |
  | ``splunkUrl`` | string | Splunk instance URL |
  | ``splunkToken`` | string | Splunk HEC token |
  | ``githubToken`` | string | GitHub personal access token |
  | ``githubRepositories`` | string[] | List of repos in ``org/repo`` format |
  | ``activeLlmProvider`` | string | Active LLM provider name |
  | ``llmConfigs`` | LlmConfig[] | LLM provider configurations |

  **Responses:**
  - ``200 OK`` — Saved ``SystemConfig`` object
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Config-Service/Get-All-Configs-Internal.request.yaml' = @"
description: |-
  Internal endpoint that returns all tenant configurations. Intended for service-to-service calls only — not exposed through the gateway.

  > ⚠️ **Internal use only.** Do not call this from client applications.

  **Responses:**
  - ``200 OK`` — Array of all ``SystemConfig`` objects
"@

  'Config-Service/Test-Connection.request.yaml' = @"
description: |-
  Tests connectivity to an external integration provider. Supports both mock validation (checks field presence) and real connection testing.

  **Path parameter:**
  | Parameter | Values | Description |
  |-----------|--------|-------------|
  | ``provider`` | ``splunk``, ``jira``, ``sonar``, ``github``, ``llm`` | The integration to test |

  **Query parameter:**
  | Parameter | Default | Description |
  |-----------|---------|-------------|
  | ``mock`` | ``true`` | If ``true``, validates config fields without making a real network call |

  **Body:** Same as ``Save Config`` — pass the relevant credentials for the provider being tested.

  **Responses:**
  - ``200 OK`` — ``{ "success": true/false, "message": "..." }``
"@

  'Incident-Service/Create-Incident.request.yaml' = @"
description: |-
  Creates a new incident (security issue or log anomaly) for the tenant. If a similar incident already exists (by title), its occurrence count is incremented instead of creating a duplicate.

  For ``HIGH`` or ``CRITICAL`` severity incidents, a Jira ticket is automatically created if Jira is configured.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body schema (``LogIssue``):**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``title`` | string | Short description of the issue |
  | ``severity`` | string | ``LOW``, ``MEDIUM``, ``HIGH``, or ``CRITICAL`` |
  | ``repository`` | string | Source repository in ``org/repo`` format |
  | ``why`` | string | Root cause explanation |
  | ``howToFix`` | string | Remediation steps |

  **Responses:**
  - ``200 OK`` — Incident created or occurrence count updated
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Incident-Service/Create-Incidents-Batch.request.yaml' = @"
description: |-
  Creates multiple incidents in a single request. Each incident is processed individually — duplicates are deduplicated by title.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body:** Array of ``LogIssue`` objects (same schema as Create Incident).

  **Responses:**
  - ``200 OK`` — All incidents processed
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Incident-Service/Get-All-Incidents.request.yaml' = @"
description: |-
  Returns all incidents for the authenticated tenant.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Responses:**
  - ``200 OK`` — Array of ``LogIssue`` objects
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Incident-Service/Get-Incidents-by-Repo.request.yaml' = @"
description: |-
  Returns all incidents for a specific repository within the tenant.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Query parameters:**
  | Parameter | Required | Description |
  |-----------|----------|-------------|
  | ``repository`` | Yes | Repository name in ``org/repo`` format |

  **Responses:**
  - ``200 OK`` — Array of ``LogIssue`` objects filtered by repository
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Incident-Service/Create-Jira-Ticket.request.yaml' = @"
description: |-
  Manually triggers Jira ticket creation for an existing incident. Useful for incidents that were created before Jira was configured, or for incidents below the auto-create severity threshold.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID (MongoDB ObjectId) |

  **Responses:**
  - ``200 OK`` — Jira ticket created
  - ``404 Not Found`` — Incident not found
"@

  'Incident-Service/Update-Severity.request.yaml' = @"
description: |-
  Updates the severity level of an existing incident and pushes the change to the linked Jira ticket (if one exists).

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID |

  **Body:**
  | Field | Type | Values |
  |-------|------|--------|
  | ``severity`` | string | ``LOW``, ``MEDIUM``, ``HIGH``, ``CRITICAL`` |

  **Responses:**
  - ``200 OK`` — Severity updated
  - ``400 Bad Request`` — Missing ``severity`` field
  - ``404 Not Found`` — Incident not found
"@

  'Incident-Service/Update-Description.request.yaml' = @"
description: |-
  Updates the ``why`` (root cause) and/or ``howToFix`` fields of an incident. If the incident has a linked Jira ticket, the description is also updated in Jira.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID |

  **Body:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``why`` | string | Updated root cause explanation |
  | ``howToFix`` | string | Updated remediation steps |

  **Responses:**
  - ``200 OK`` — Description updated
  - ``404 Not Found`` — Incident not found
  - ``500 Internal Server Error`` — Jira update failed
"@

  'Incident-Service/Sync-Jira-Ticket.request.yaml' = @"
description: |-
  Force-syncs the incident's state from Jira, pulling the latest status, comments, and transitions back into the local incident record.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID |

  **Responses:**
  - ``200 OK`` — Sync complete
  - ``404 Not Found`` — Incident not found
  - ``500 Internal Server Error`` — Jira sync failed
"@

  'Incident-Service/Add-Jira-Comment.request.yaml' = @"
description: |-
  Adds a comment to the linked Jira ticket and then syncs the ticket state back to the local incident.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID |

  **Body:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``body`` | string | Comment text to post to Jira |

  **Responses:**
  - ``200 OK`` — Comment added and ticket synced
  - ``400 Bad Request`` — Missing ``body`` field
  - ``404 Not Found`` — Incident not found
"@

  'Incident-Service/Get-Jira-Transitions.request.yaml' = @"
description: |-
  Retrieves the available workflow transitions for the linked Jira ticket (e.g. "To Do → In Progress → Done"). Use the returned ``transitionId`` values with the Transition Jira Ticket endpoint.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID |

  **Responses:**
  - ``200 OK`` — Array of transition objects: ``[{ "id": "31", "name": "In Progress" }, ...]``
  - ``404 Not Found`` — Incident not found
"@

  'Incident-Service/Transition-Jira-Ticket.request.yaml' = @"
description: |-
  Moves the linked Jira ticket to a new workflow state and syncs the updated status back to the local incident.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Incident ID |

  **Body:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``transitionId`` | string | Jira transition ID (from Get Jira Transitions) |
  | ``transitionName`` | string | Human-readable transition name (optional, for logging) |

  **Responses:**
  - ``200 OK`` — Transition applied and ticket synced
  - ``400 Bad Request`` — Missing ``transitionId``
  - ``404 Not Found`` — Incident not found
"@

  'Rules/Get-Rule-Knowledge.request.yaml' = @"
description: |-
  Retrieves the stored knowledge base entry for a SonarQube rule key, including the root cause explanation and remediation steps.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``ruleKey`` | SonarQube rule key (e.g. ``java:S3649``) |

  **Responses:**
  - ``200 OK`` — ``RuleKnowledge`` object
  - ``404 Not Found`` — No knowledge entry for this rule key
"@

  'Rules/Save-Rule-Knowledge.request.yaml' = @"
description: |-
  Creates or updates a knowledge base entry for a SonarQube rule. If an entry for the ``ruleKey`` already exists, it is updated in place.

  **Body schema (``RuleKnowledge``):**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``ruleKey`` | string | SonarQube rule key (e.g. ``java:S3649``) — required |
  | ``why`` | string | Explanation of why this rule violation is dangerous |
  | ``howToFix`` | string | Step-by-step remediation guidance |
  | ``organization`` | string | Organization scope for this knowledge entry |

  **Responses:**
  - ``200 OK`` — Saved ``RuleKnowledge`` object
  - ``400 Bad Request`` — Missing ``ruleKey``
"@

  'Log-Analyzer-Service/Analyze-Logs.request.yaml' = @"
description: |-
  Submits raw log lines for AI-powered analysis. Each log entry is analyzed by the configured LLM provider to detect anomalies and security incidents. Detected incidents are automatically forwarded to the Incident Service.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body:** Array of raw log strings.

  ```json
  [
    "ERROR 2024-01-01T10:00:00 NullPointerException at com.app.Service:42",
    "WARN 2024-01-01T10:01:00 Connection timeout to database"
  ]
  ```

  **Responses:**
  - ``200 OK`` — Analysis triggered (fire-and-forget; incidents are forwarded asynchronously)
  - No body returned
"@

  'Log-Collector-Service/Export-Mock-Splunk-Logs.request.yaml' = @"
description: |-
  Mock Splunk export endpoint that simulates a Splunk log export API. Returns a random subset of pre-loaded log entries. Has a 40% chance of returning an empty list to simulate log silence.

  > 🔧 **Development/testing only.** This endpoint is used by the log-collector-service to simulate Splunk integration without a real Splunk instance.

  **Direct service URL:** ``http://localhost:8083`` (not proxied through the gateway)

  **Responses:**
  - ``200 OK`` — Array of log strings (0–5 entries), each prefixed with ``[MOCK-SPLUNK] <timestamp>``
"@

  'Repo-Scanner-Service/Trigger-Scan.request.yaml' = @"
description: |-
  Triggers an asynchronous DevSecOps scan of a GitHub repository using SonarQube/SonarCloud. The scan runs in a background thread and detected issues are forwarded to the Incident Service.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Query parameters:**
  | Parameter | Required | Description |
  |-----------|----------|-------------|
  | ``repo`` | Yes | Repository name in ``org/repo`` format |

  **Responses:**
  - ``202 Accepted`` — Scan started (runs asynchronously)
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Repo-Scanner-Service/Auto-Fix-Issue.request.yaml' = @"
description: |-
  Automatically creates a GitHub Pull Request with a code fix for a detected security issue. Uses the LLM-generated fix suggestion to patch the affected file and open a PR.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body:**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``repository`` | string | Repository in ``org/repo`` format |
  | ``filePath`` | string | Path to the affected file within the repo |
  | ``exactCodeFix`` | string | The exact code change to apply |
  | ``issueTitle`` | string | Title of the issue being fixed (used in PR title) |

  **Responses:**
  - ``200 OK`` — ``{ "prUrl": "https://github.com/org/repo/pull/42" }``
  - ``400 Bad Request`` — Missing required fields
  - ``500 Internal Server Error`` — PR creation failed
"@

  'Repo-Scanner-Service/Regenerate-Issue-Description.request.yaml' = @"
description: |-
  Re-generates the AI-written ``why`` and ``howToFix`` description for an existing incident using the currently configured LLM provider. Useful when the LLM provider or model has been updated.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body (``LogIssueDto``):**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``title`` | string | Issue title |
  | ``severity`` | string | Issue severity |
  | ``repository`` | string | Source repository |

  **Responses:**
  - ``200 OK`` — ``{ "why": "...", "howToFix": "..." }``
  - ``500 Internal Server Error`` — LLM call failed
"@

  'Mock-SonarQube/Search-Issues.request.yaml' = @"
description: |-
  Mock SonarQube issues search endpoint. Returns a random subset (2–5) of pre-loaded realistic security issues including SQL injection, hardcoded credentials, XSS, and code smells.

  > 🔧 **Development/testing only.** Simulates the SonarQube ``GET /api/issues/search`` endpoint.

  **Direct service URL:** ``http://localhost:8085`` (not proxied through the gateway)

  **Responses:**
  - ``200 OK`` — ``{ "issues": [ { "rule": "java:S3649", "type": "VULNERABILITY", "severity": "CRITICAL", ... } ] }``
"@

  'Mock-SonarQube/Show-Rule.request.yaml' = @"
description: |-
  Mock SonarQube rule detail endpoint. Returns a simulated rule description with HTML content including non-compliant and compliant code examples.

  > 🔧 **Development/testing only.** Simulates the SonarQube ``GET /api/rules/show`` endpoint.

  **Direct service URL:** ``http://localhost:8085`` (not proxied through the gateway)

  **Responses:**
  - ``200 OK`` — ``{ "rule": { "htmlDesc": "<h2>Description</h2>..." } }``
"@

  'Notifications/Create-Notification.request.yaml' = @"
description: |-
  Creates a new notification for the tenant. Notifications are pushed to connected SSE clients in real time.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Body (``Notification``):**
  | Field | Type | Description |
  |-------|------|-------------|
  | ``title`` | string | Notification title |
  | ``message`` | string | Notification body text |
  | ``type`` | string | ``INFO``, ``WARNING``, or ``ERROR`` |

  **Responses:**
  - ``200 OK`` — Created ``Notification`` object
  - ``400 Bad Request`` — Missing ``X-Tenant-Id`` header
"@

  'Notifications/Get-Recent-Notifications.request.yaml' = @"
description: |-
  Returns recent notifications for the authenticated tenant.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |

  **Responses:**
  - ``200 OK`` — Array of ``Notification`` objects
"@

  'Notifications/Stream-Notifications-SSE.request.yaml' = @"
description: |-
  Opens a Server-Sent Events (SSE) stream that pushes new notifications to the client in real time as they are created.

  **Required headers:**
  | Header | Description |
  |--------|-------------|
  | ``X-Tenant-Id`` | Tenant identifier |
  | ``Accept`` | Must be ``text/event-stream`` |

  > 💡 This is a long-lived streaming connection. The client receives ``Notification`` objects as SSE events whenever a new notification is created for the tenant.

  **Responses:**
  - ``200 OK`` — SSE stream (content-type: ``text/event-stream``)
"@

  'Notifications/Mark-Notification-as-Read.request.yaml' = @"
description: |-
  Marks a specific notification as read.

  **Path parameter:**
  | Parameter | Description |
  |-----------|-------------|
  | ``id`` | Notification ID |

  **Responses:**
  - ``200 OK`` — Updated ``Notification`` object with ``read: true``
  - ``404 Not Found`` — Notification not found
"@
}

$baseDir = 'postman/collections/DevOps-Pro-API'
$successCount = 0
$failCount = 0

foreach ($relPath in $descriptions.Keys) {
  $filePath = Join-Path $baseDir $relPath
  
  if (-not (Test-Path $filePath)) {
    Write-Host "MISSING: $filePath"
    $failCount++
    continue
  }
  
  $content = [System.IO.File]::ReadAllText($filePath)
  
  # Check if description already exists
  if ($content -match 'description:') {
    Write-Host "SKIP (already has description): $relPath"
    $successCount++
    continue
  }
  
  # Find the position right after the name: line (end of that line)
  # Pattern: find "\r\nmethod:" and insert description before it
  $insertMarker = "`r`nmethod:"
  $idx = $content.IndexOf($insertMarker)
  
  if ($idx -lt 0) {
    # Try without name line - insert after $kind line
    $insertMarker = "`r`nname:"
    $idx = $content.IndexOf($insertMarker)
    if ($idx -lt 0) {
      Write-Host "ERROR: Cannot find insertion point in $relPath"
      $failCount++
      continue
    }
    # Find end of name line
    $endOfNameLine = $content.IndexOf("`r`n", $idx + 1)
    if ($endOfNameLine -lt 0) { $endOfNameLine = $content.Length }
    else { $endOfNameLine += 2 } # skip past \r\n
    $insertPos = $endOfNameLine
  } else {
    $insertPos = $idx + 2  # skip past \r\n, insert before "method:"
  }
  
  $descText = $descriptions[$relPath]
  # The description text already has the key, just need to insert it with CRLF line endings
  $descWithCRLF = $descText -replace '\r?\n', "`r`n"
  
  $newContent = $content.Substring(0, $insertPos) + $descWithCRLF + $content.Substring($insertPos)
  
  [System.IO.File]::WriteAllText($filePath, $newContent, [System.Text.Encoding]::UTF8)
  Write-Host "OK: $relPath"
  $successCount++
}

Write-Host ""
Write-Host "Done. Success: $successCount, Failed: $failCount"
