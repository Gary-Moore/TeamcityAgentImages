# 🗂 Project Structure: Docker Build Agents

This repository contains scripts and configuration for building, testing, and publishing custom Docker images used as TeamCity build agents for both Linux and Windows environments.

---

## 📁 Top-Level Layout

```
DOCKER-BUILD-AGENTS/
├── common/
├── docs/
├── linux-agent/
├── windows-agent/
├── .gitignore
└── README.md
```

---

## 🔍 Folder & File Breakdown

### 📦 `/common/`
Shared configuration files and TeamCity usage references.

- `CHANGELOG.md` — Log of meaningful changes to scripts and pipeline logic
- `teamcity-template-example.md` — Example build step layout for UI-based TeamCity configurations

---

### 📖 `/docs/`
Developer-facing documentation, designed to be browsed in GitHub or rendered by TechDocs in Backstage (in future).

- `developer-onboarding.md` — Internal guide for understanding and contributing to this repo
- `image-versioning-guidance.md` — Explains tagging conventions, metadata, and digests
- `README.md` — (Optional) Homepage if using Docs site generator

---

### 🐧 `/linux-agent/`
Scripts and configuration for the Linux-based TeamCity build agent image.

- `.env.example` — Sample values for local testing
- `build-image.sh` — Builds the Docker image
- `publish-image.sh` — Pushes the image to ACR, with tagging
- `test-image.sh` — Runs basic smoke tests
- `dotnetagent.dockerfile` — Dockerfile for .NET-based Linux build agent

---

###  `/windows-agent/`
Scripts and configuration for the Windows-based TeamCity build agent image.

- `build-image.ps1` — Builds the Docker image
- `publish-image.ps1` — Pushes the image to ACR, with tagging
- `test-image.ps1` — Runs validation steps
- `dotnetframeworkagent.dockerfile` — Dockerfile for Windows-based .NET Framework build agent

---
