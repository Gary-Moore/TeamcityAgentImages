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


## ACR Task (Linux agent): build → smoke → push (+ optional aliases)

**Task file:** `acr/teamcity-agent.linux.yaml`  
**Dockerfile:** `docker/linux/dotnet-agent/dotnetagent.dockerfile`  
**Smoke test (baked in image):** `docker/linux/dotnet-agent/test-image.sh`

### What it does
1. **Build** the image with runtime args (base image, .NET channel, Node major, CA pin).
2. **Smoke test** the freshly built image; prints a delimited JSON block to logs:

```
PDS_RUNTIME_JSON_START
{ ...runtime info... }
PDS_RUNTIME_JSON_END
```

3. **Push** the primary immutable tag, plus **optional alias tags** if provided.

### Required values (`--set`)
- `image_tag` – immutable tag, e.g. `2025.08-linux-sudo-dotnet8-node21`
- `base_image` – e.g. `jetbrains/teamcity-agent:2025.07-linux-sudo`
- `dotnet_sdk_version` – e.g. `8.0`
- `node_major` – e.g. `21`
- `entrust_url` – CA cert URL
- `entrust_sha256` – CA SHA256 (pass with `--set-secret`)

### Optional values
- `alias_tag1`, `alias_tag2` – e.g. `dotnet8-node21`, `dotnet8`

### Example: trigger from TeamCity
```bash
az acr task run \
-r "$ACR_NAME" \
-n "$ACR_TASK_NAME" \
--set image_tag="2025.08-linux-sudo-dotnet8-node21" \
--set base_image="jetbrains/teamcity-agent:2025.07-linux-sudo" \
--set dotnet_sdk_version="8.0" \
--set node_major="21" \
--set entrust_url="https://…/Entrust_OV_TLS_Issuing_RSA_CA_2.crt" \
--set-secret entrust_sha256="***" \
--set alias_tag1="dotnet8-node21" \
--set alias_tag2="dotnet8"
```


## Notes

- Safe to re-run: script will update if task already exists.
- The YAML (acr/teamcity-agent.linux.yaml) defines build steps and image tags; you don’t need to pass --image here.
- TeamCity CI jobs should only call az acr task run …, not this provisioning script.