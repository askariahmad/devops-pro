---
name: jenkins
description: "Guidelines and procedures for managing local Jenkins configurations, pipeline setups, credentials, and job configuration updates in the DevOps-Pro project."
---

# Skill: Jenkins Pipeline Management

This skill provides procedures for setting up, managing, and automating Jenkins CI/CD pipelines in local development and production-like emulated environments.

## 1. Running Jenkins Locally
Run Jenkins in Docker with host Docker socket mounted (enabling image building) and project workspace directory bind-mounted:
```powershell
docker run -d -p 9090:8080 -p 50000:50000 --name jenkins-local -u 0 -e JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home -v c:\Users\ahmad\IdeaProjects\devops-pro:/workspace jenkins/jenkins:lts-jdk21
```

## 2. Programmatic Job Import
To create or update a Jenkins job without API credentials, write a `config.xml` file directly to the Jenkins home directory on disk, then reload or restart the container:
1. Create `/var/jenkins_home/jobs/<job-name>/config.xml`.
2. Set ownership: `chown -R jenkins:jenkins /var/jenkins_home/jobs/<job-name>`.
3. Restart: `docker restart jenkins-local`.

## 3. Git safe.directory & Submodule Transport Configs
To bypass ownership security warnings in containers accessing mounted volumes and allow cloning of local submodules, configure Git to trust all directories and allow `file` protocol transports:
```bash
git config --global --add safe.directory '*'
git config --global protocol.file.allow always
```

## 4. .NET Globalization Invariant Override
When running PowerShell Core (`pwsh`) inside minimal Linux container environments, the engine can crash due to missing `libicu` dependencies. Ensure you inject the following environment variable globally:
```groovy
environment {
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = 'true'
}
```

## 5. Local Submodule SCM Checkout Configuration
When cloning microservice submodules from local paths (`./config-service` relative URLs), SCM checkouts must disable `trackingSubmodules`. Otherwise, Git crashes trying to locate remote references:
```groovy
checkout([$class: 'GitSCM', 
    branches: [[name: '*/feat/azure-migration']], 
    extensions: [[$class: 'SubmoduleOption', recursiveSubmodules: true, disableSubmodules: false, trackingSubmodules: false]], 
    userRemoteConfigs: [[url: 'file:///workspace']]
])
```

## 6. Self-Healing Tool Bootstrap
To support zero-config, portable deployments across fresh container instances, include a bootstrap check at the beginning of the pipeline to verify and automatically install missing tools:
- Checks for `pwsh`, `terraform`, `kubectl`, `npm`, and `mvn`.
- Installs PowerShell via tarball to bypass Debian library version mismatches.
- Installs other CLI tools via `apt-get` non-interactively.

