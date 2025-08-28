#!/usr/bin/env bash
set -euo pipefail

# ---- Required env ----
: "${AZ_TENANT_ID:?Missing: set AZ_TENANT_ID for Azure login}"
: "${AZ_CLIENT_ID:?Missing: set AZ_CLIENT_ID for Azure login}"
: "${AZ_CLIENT_SECRET:?Missing: set AZ_CLIENT_SECRET for Azure login}"
: "${AZ_SUBSCRIPTION_ID:?Missing: set AZ_SUBSCRIPTION_ID for Azure login}"

: "${ACR_NAME:?Missing: set ACR_NAME for ACR task (e.g. myacr)}"
: "${ACR_TASK_NAME:?Missing: set ACR_TASK_NAME for ACR task (e.g. mytask)}"

: "${IMAGE_TAG:?Missing: set IMAGE_TAG for ACR task (e.g. latest)}"
: "${DOTNET_SDK_VERSION:?Missing: set DOTNET_SDK_VERSION for ACR task (e.g. 8.0)}"
: "${NODE_MAJOR:?Missing: set NODE_MAJOR for ACR task (e.g. 18)}"
: "${ENTRUST_URL:?Missing: set ENTRUST_URL for ACR task (e.g. https://entrust.example.com)}"
: "${ENTRUST_SHA256:?Missing: set ENTRUST_SHA256 for ACR task (e.g. abc123...)}"

az login --service-principal -u "$AZ_CLIENT_ID" -p "$AZ_CLIENT_SECRET" --tenant "$AZ_TENANT_ID" >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID"

# ---- Run task and capture Run ID ----
echo "Running ACR Task '$ACR_TASK_NAME' on registry '$ACR_NAME' for tag '$IMAGE_TAG'"
RUN_JSON="$(az acr task run \
    -r "$ACR_NAME" \
    -n "$ACR_TASK_NAME" \
    --set image_tag="$IMAGE_TAG" \
    --set dotnet_sdk_version="$DOTNET_SDK_VERSION" \
    --set node_major="$NODE_MAJOR" \
    --set base_images="$BASE_IMAGES" \
    --set entrust_url="$ENTRUST_URL" \
    --set-secret entrust_sha256="$ENTRUST_SHA256" \
    --no-logs -o json)"

RUN_ID="$(printf '%s' "$RUN_JSON" | jq -r '.runId')"
echo "Queued ACR task run with ID: $RUN_ID"

# ---- Fetch logs and extract the delimited JSON ----
LOG_TXT="$(az acr task logs -r "$ACR_NAME" --run-id "$RUN_ID")"

# ---- Persist raw logs ----
printf '%s\n' "$LOG_TXT" > acr-task-$RUN_ID.log

RUNTIME_JSON="$(printf '%s\n' "$LOG_TXT" | awk '/PDS_RUNTIME_JSON_START/,/PDS_RUNTIME_JSON_END/' | sed 'id;$d')"

if [[ -z "$RUNTIME_JSON" ]]; then
     echo "ERROR: Could not locate PDS_RUNTIME_JSON in ACR logs for run $RUN_ID"
     exit 1
fi

printf '%s\n' "$RUNTIME_JSON" > pds-runtime.json