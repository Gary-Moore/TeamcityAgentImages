#!/usr/bin/env bash
# Generic ACR Task runner:
# - Logs into Azure with a Service Principal
# - Triggers a named ACR Task with IMAGE_TAG + any extra --set/--set-secret args
# - Polls run status, always fetches logs
# - Extracts runtime JSON and writes manifest.json
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
POLL_SLEEP="${POLL_SLEEP:-5}"         # seconds between polls
MAX_WAIT_SECS="${MAX_WAIT_SECS:-1200}"
RUN_ID=""

# ---- Azure login ----
az login --service-principal -u "$AZ_CLIENT_ID" -p "$AZ_CLIENT_SECRET" --tenant "$AZ_TENANT_ID" >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID"

# Always fetch logs if we have a RUN_ID and exit unexpectedly
cleanup() {
  if [[ -n "${RUN_ID:-}" ]]; then
    az acr task logs -r "$ACR_NAME" --run-id "$RUN_ID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ---- Trigger task (queue only) ----
echo "Running ACR Task '$ACR_TASK_NAME' on '$ACR_NAME' for tag '$IMAGE_TAG'..."
RUN_JSON="$(az acr task run -r "$ACR_NAME" -n "$ACR_TASK_NAME" \
  --set image_tag="$IMAGE_TAG" \
  "$@" \
  --no-logs --no-wait -o json)"

# Extract runId robustly (jq or sed)
if command -v jq >/dev/null 2>&1; then
  RUN_ID="$(printf '%s' "$RUN_JSON" | jq -r '.runId')"
else
  RUN_ID="$(printf '%s' "$RUN_JSON" | sed -n 's/.*"runId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

if [[ -z "${RUN_ID:-}" || "$RUN_ID" == "null" ]]; then
  echo "ERROR: Could not determine ACR runId. Raw response:"
  echo "$RUN_JSON"
  exit 1
fi
echo "Queued ACR task run: $RUN_ID"
# Expose to TeamCity for downstream steps
echo "##teamcity[setParameter name='env.ACR_RUN_ID' value='${RUN_ID}']"

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
LOG_TXT="$(az acr task logs -r "$ACR_NAME" --run-id "$RUN_ID" 2>/dev/null || true)"
printf '%s\n' "$LOG_TXT" > "acr-task-${RUN_ID}.log"
# Publish log to TeamCity, if running under it
echo "##teamcity[publishArtifacts 'acr-task-${RUN_ID}.log']" || true

# ---- Extract runtime JSON (portable, no grep -P) ----
# Supports either a block:
#   PDS_RUNTIME_JSON_START
#   { ... }
#   PDS_RUNTIME_JSON_END
# or a single-line:
#   PDS_RUNTIME_JSON: { ... }
BLOCK_JSON="$(printf '%s\n' "$LOG_TXT" \
  | sed -n '/PDS_RUNTIME_JSON_START/,/PDS_RUNTIME_JSON_END/p' \
  | sed '1d;$d')"

if [[ -z "$BLOCK_JSON" ]]; then
  SINGLE_JSON="$(printf '%s\n' "$LOG_TXT" \
    | sed -n 's/.*PDS_RUNTIME_JSON:[[:space:]]*//p' \
    | sed -n '1p')"
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
  echo "Wrote pds-runtime.json"
else
  echo "No runtime JSON found in logs (expected if build failed before smoke)."
fi

# ---- Resolve built image digest (if succeeded) ----
DIGEST=""
if [[ "$status" == "Succeeded" ]]; then
  # Get the digest of the just-built tag
  DIGEST="$(az acr repository show -n "$ACR_NAME" \
    --image "${IMAGE_REPOSITORY}:${IMAGE_TAG}" \
    --query digest -o tsv 2>/dev/null || echo '')"
  if [[ -n "$DIGEST" ]]; then
    echo "Resolved digest for ${IMAGE_REPOSITORY}:${IMAGE_TAG} -> ${DIGEST}"
    echo "##teamcity[setParameter name='env.IMAGE_DIGEST' value='${DIGEST}']"
  else
    echo "WARNING: Could not resolve digest for ${IMAGE_REPOSITORY}:${IMAGE_TAG}"
  fi
fi

# ---- Write manifest.json (if we have digest or runtime) ----
if [[ -n "${DIGEST}${RUNTIME_JSON}" ]]; then
  cat > manifest.json <<EOF
{
  "image": "${ACR_LOGIN_SERVER}/${IMAGE_REPOSITORY}:${IMAGE_TAG}",
  "tag": "${IMAGE_TAG}",
  "repository": "${IMAGE_REPOSITORY}",
  "loginServer": "${ACR_LOGIN_SERVER}",
  "runId": "${RUN_ID}",
  "digest": "${DIGEST}",
  "runtime": ${RUNTIME_JSON:-null}
}
EOF
  echo "Wrote manifest.json"
  echo "##teamcity[publishArtifacts 'manifest.json']" || true
fi

# ---- Exit with the run’s outcome ----
if [[ "$status" != "Succeeded" ]]; then
  echo "ACR task run failed; see acr-task-${RUN_ID}.log"
  exit 1
fi

echo "Done. Artifacts: manifest.json (if present), pds-runtime.json (if present), acr-task-${RUN_ID}.log"