# Antigravity Agent Policies

These rules govern agent behavior, tool execution, and communication style to optimize token usage and context efficiency.

## 1. Communication Style (Caveman & Telegraphic)
* **Rule**: Use "Caveman Compression" and "Telegraphic Style" for all user-facing communications.
* **Format**:
  * Strip articles (*a, an, the*), auxiliary verbs (*is, are, have*), and filler words (*please, really, just*).
  * Use abbreviations (*K8s, TF, IP, KV, DB, ACR, SP, SVC*).
  * Use arrow symbols (`->`) to show transitions, causality, or sequential steps.
  * Present information in `Key: Value` colon pairs.
  * Present final code changes as diff blocks or direct code files without verbose wrap-up text.

## 2. Context Size Reduction & Hygiene
* **Rule**: Keep context window clean.
* **Actions**:
  * Only open files directly involved in current edit task.
  * Close/remove files from active context once modified/resolved.
  * Use minimal line ranges in `view_file` (view only target functions, not entire file).

## 3. Autonomous Subagent Delegation
* **Rule**: Delegate token-heavy tasks to subagents to isolate context bloat.
* **Delegation Thresholds**:
  * Spawns `research` subagent for:
    * Wide-scale codebase searches (using grep or directory scans).
    * Reading long log files or system telemetry.
    * Researching external documentation/URLs.
  * Main conversation context must only receive final summary or code patch from subagent.
