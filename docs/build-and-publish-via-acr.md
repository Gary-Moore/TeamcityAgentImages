# Provisioning Scripts

This folder contains helper scripts for managing ACR Tasks used to build and publish TeamCity agent images.

`provision-acr-task-linux.sh`

Idempotently creates or updates the Linux ACR Task (`tc-agent-linux`).
Intended to be run manually (or via a dedicated TeamCity job) when bootstrapping a new environment or changing the ACR Task definition.

## Prerequisites

- Azure CLI installed (az ≥ 2.60)
- Service Principal credentials with:
    - ACR Contributor on the registry
    - Reader on the resource group (for az acr show)
- GitHub PAT (repo read scope) if the repo is private
- bash (tested on Linux/macOS, Git Bash on Windows)

Example usage (local shell)
```bash
# --- Azure SP creds ---
export AZ_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export AZ_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export AZ_CLIENT_SECRET="super-secret"
export AZ_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# --- ACR + Task config ---
export AZ_RESOURCE_GROUP="rg-container-reg"
export ACR_NAME="gammawebdevops"
export ACR_TASK_NAME="tc-agent-linux"
export TASK_FILE="acr/teamcity-agent.linux.yaml"
export GIT_CONTEXT="https://github.com/Gary-Moore/TeamcityAgentImages.git#main"

# --- GitHub PAT (secure!) ---
export GIT_ACCESS_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# --- Run script ---
./scripts/provision-acr-task-linux.sh
```

## Output

- On success: task will be created/updated and details printed in table form.
- A JSON copy of the task definition will be written to acr-task.json (useful for TeamCity artifacts).

## Notes

- Safe to re-run: script will update if task already exists.
- The YAML (acr/teamcity-agent.linux.yaml) defines build steps and image tags; you don’t need to pass --image here.
- TeamCity CI jobs should only call az acr task run …, not this provisioning script.