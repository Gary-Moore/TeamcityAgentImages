#!/usr/bin/env bash
# Idempotently create/update the ACR Task that builds the TeamCity Linux agent image.
set -euo pipefail

# ---- Inputs (env vars or pass in via TeamCity parameters) ----
: "${AZ_TENANT_ID:?Missing: set AZ_TENANT_ID for Azure login}"
: "${AZ_CLIENT_ID:?Missing: set AZ_CLIENT_ID for Azure login}"
: "${AZ_CLIENT_SECRET:?Missing: set AZ_CLIENT_SECRET for Azure login}"
: "${AZ_SUBSCRIPTION_ID:?Missing: set AZ_SUBSCRIPTION_ID for Azure login}"
: "${RESOURCE_GROUP:?Missing: set AZ_RESOURCE_GROUP for Azure login}"
: "${ACR_NAME:?Missing: set ACR_NAME for ACR task (e.g. gammawebdevops)}"
: "${ACR_TASK_NAME:?Missing: set ACR_TASK_NAME for ACR task (e.g. tc-agent-linux)}"
: "${TASK_FILE:?Missing: set TASK_FILE for ACR task (e.g. acr/teamcity-agent.linux.yaml)}"
: "${GIT_CONTEXT:?Missing: set GIT_CONTEXT for ACR task (e.g. https://github.com/org/repo.git#main)}"
: "${GIT_ACCESS_TOKEN:?Missing: set GIT_ACCESS_TOKEN (read access to private repo)}"

# ---- Login to Azure ----
az login --service-principal -u "$AZ_CLIENT_ID" -p "$AZ_CLIENT_SECRET" --tenant "$AZ_TENANT_ID" >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID"

echo "Checking ACR '$ACR_NAME' in RG '$RESOURCE_GROUP'..."
az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query "sku.name" -o tsv >/dev/null

# ---- Create or Update ACR Task ----
if az acr task show -g "$RESOURCE_GROUP" -r "$ACR_NAME" -n "$ACR_TASK_NAME" >/dev/null 2>&1; then
  echo "Updating ACR Task '$ACR_TASK_NAME' in RG '$RESOURCE_GROUP'..."
  az acr task update \
    -g "$RESOURCE_GROUP" \
    -r "$ACR_NAME" \
    -n "$ACR_TASK_NAME" \
    --file "$TASK_FILE" \
    --context "$GIT_CONTEXT" \
    --commit-trigger-enabled false \
    --pull-request-trigger-enabled false \
    --base-image-trigger-enabled true \
    --git-access-token "$GIT_ACCESS_TOKEN" \
    --timeout 3600 >/dev/null
else
  echo "Creating ACR Task '$ACR_TASK_NAME' in RG '$RESOURCE_GROUP'..."
  az acr task create \
    -g "$RESOURCE_GROUP" \
    -r "$ACR_NAME" \
    -n "$ACR_TASK_NAME" \
    --file "$TASK_FILE" \
    --context "$GIT_CONTEXT" \
    --commit-trigger-enabled false \
    --pull-request-trigger-enabled false \
    --base-image-trigger-enabled true \
    --git-access-token "$GIT_ACCESS_TOKEN" \
    --timeout 3600 >/dev/null
fi

# ---- Output summary ----
az acr task show -g "$RESOURCE_GROUP" -r "$ACR_NAME" -n "$ACR_TASK_NAME" -o json > acr-task.json
echo "Provisioned task:"
az acr task show -g "$RESOURCE_GROUP" -r "$ACR_NAME" -n "$ACR_TASK_NAME" -o table
echo "Wrote ACR task definition to './acr-task.json'"
