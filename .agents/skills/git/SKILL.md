---
name: git
description: "Guidelines and procedures for managing Git repositories, submodules, local checkouts, relative paths, and commit hooks in the DevOps-Pro project."
---

# Skill: Git & Submodule Management

This skill captures runbooks and rules for handling Git workflows, specifically multi-module submodules and local test repositories in containerized and offline settings.

## 1. Local Submodule Commits
Because microservices are structured as Git submodules, code changes inside them must be committed in their individual repository directories first:
```bash
# 1. Commit inside each modified submodule
git submodule foreach "git commit -a -m 'your commit message' || true"

# 2. Add and commit the updated submodule pointers in the parent repository
git add config-service gateway-service incident-service ...
git commit -m "chore: update submodule references"
```

## 2. Relative Submodule Paths for Local Repositories
To allow offline/containerized clones to inherit local modifications without pushing to GitHub, convert remote URLs in `.gitmodules` to relative repository paths:
```ini
[submodule "config-service"]
	path = config-service
	url = ./config-service
```

## 3. Git safe.directory Configuration
Newer Git clients throw security errors (`fatal: detected dubious ownership`) when reading repositories mounted as Docker volumes from a different host user:
```bash
git config --global --add safe.directory '*'
```

## 4. Local File Protocol Transport Security
To clone submodules over local folders or `file://` protocols recursively:
```bash
git config --global protocol.file.allow always
```
