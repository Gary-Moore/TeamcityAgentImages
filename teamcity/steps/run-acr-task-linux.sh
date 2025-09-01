#!/usr/bin/env bash
# Generic ACR Task runner:
# - Logs into Azure with a Service Principal
# - Triggers a named ACR Task with IMAGE_TAG + any extra --set/--set-secret args
# - Polls run status, always fetches logs
# - Extracts runtime JSON and writes manifest.json
# - Optionally creates alias tags inside ACR
set -euo pipefail

# ---- Required env ----
: "${AZ_TENANT_ID:?Missing AZ_TENANT_ID}"
: "${AZ_CLIENT_ID:?Missing AZ_CLIENT_ID}"
: "${AZ_CLIENT_SECRET:?Missing AZ_CLIENT_SECRET}"
: "${AZ_SUBSCRIPTION_ID:?Missing AZ_SUBSCRIPTION_ID}"
: "${ACR_NAME:?Missing ACR_NAME (short name, e.g. gammawebdevops)}"
: "${ACR_TASK_NAME:?Missing ACR_TASK_NAME (e.g. tc-agent-linux)}"
: "${IMAGE_TAG:?Missing IMAGE_TAG (immutable, e.g. 2025.09-linux-dotnet8-node22)}"

# ---- Defaults ----
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-teamcity/agent}"
ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-${ACR_NAME}.azurecr.io}"
ALIAS_TAGS="${ALIAS_TAGS:-}"   # space-delimited e.g. "dotnet8-node22 dotnet8 latest"

# ---- Azure login ----
az login --service-principal -u "$AZ_CLIENT_ID" -p "$AZ_CLIENT_SECRET" --tenant "$AZ_TENANT_ID" >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID"

# ---- Trigger task (queue only) ----
echo "Running ACR Task '$ACR_TASK_NAME' on '$ACR_NAME' for tag '$IMAGE_TAG'..."
RUN_JSON="$(az acr task run -r "$ACR_NAME" -n "$ACR_TASK_NAME" \
  --set image_tag="$IMAGE_TAG" \
  "$@" \
  --no-logs --no-wait -o json)"

RUN_ID="$(printf '%s' "$RUN_JSON" | jq -r '.runId')"
if [[ -z "${RUN_ID:-}" || "$RUN_ID" == "null" ]]; then
  echo "ERROR: Could not determine ACR runId. Raw response:"
  echo "$RUN_JSON"
  exit 1
fi
echo "Queued ACR task run: $RUN_ID"
echo "Waiting for run to complete..."

# ---- Poll until completion ----
status=""
while :; do
  status="$(az acr task show-run -r "$ACR_NAME" --run-id "$RUN_ID" --query status -o tsv 2>/dev/null || echo '-')"
  case "$status" in
    Succeeded|Failed|Canceled) break ;;
    Queued|Running|"") sleep 5 ;;
    *) echo "Unknown status: $status (continuing)"; sleep 5 ;;
  esac
done
echo "Run $RUN_ID finished with status: $status"

# ---- Fetch logs (always) ----
LOG_TXT="$(az acr task logs -r "$ACR_NAME" --run-id "$RUN_ID" 2>/dev/null || echo '')"
printf '%s\n' "$LOG_TXT" > "acr-task-${RUN_ID}.log"

# ---- Extract runtime JSON ----
BLOCK_JSON="$(printf '%s\n' "$LOG_TXT" | awk '/PDS_RUNTIME_JSON_START/,/PDS_RUNTIME_JSON_END/' | sed '1d;$d' || true)"
if [[ -z "$BLOCK_JSON" ]]; then
  SINGLE_JSON="$(printf '%s\n' "$LOG_TXT" | grep -oP 'PDS_RUNTIME_JSON:\s*\K\{.*\}' || true)"
else
  SINGLE_JSON=""
fi
RUNTIME_JSON="${BLOCK_JSON:-$SINGLE_JSON}"

if [[ -n "$RUNTIME_JSON" ]]; then
  if command -v jq >/dev/null 2>&1; then
    printf '%s\n' "$RUNTIME_JSON" | jq -c . > pds-runtime.json
  else
    printf '%s\n' "$RUNTIME_JSON" > pds-runtime.json
  fi

  cat > manifest.json <<EOF
{
  "image": "${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${IMAGE_TAG}",
  "tag": "${IMAGE_TAG}",
  "runId": "${RUN_ID}",
  "runtime": $(cat pds-runtime.json)
}
EOF
  echo "Wrote manifest.json and pds-runtime.json"
else
  echo "No runtime JSON found in logs (expected if build failed before smoke)."
fi

# ---- Optional: alias tags (only if run succeeded) ----
if [[ "$status" == "Succeeded" && -n "${ALIAS_TAGS// /}" ]]; then
  for alias in $ALIAS_TAGS; do
    echo "Creating alias tag '${alias}' for ${IMAGE_REPOSITORY}:${IMAGE_TAG} in registry..."
    az acr import -n "$ACR_NAME" \
      -s "${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
      -t "${IMAGE_REPOSITORY}:${alias}" --force
  done
fi

# ---- Exit with the run’s outcome ----
if [[ "$status" != "Succeeded" ]]; then
  echo "ACR task run failed; see acr-task-${RUN_ID}.log"
  exit 1
fi

echo "Done. Artifacts: manifest.json, pds-runtime.json, acr-task-${RUN_ID}.log"