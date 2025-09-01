#!/usr/bin/env bash
set -euo pipefail

json="/opt/pds-runtime.json"

if [[ ! -f "$json" ]]; then
  echo "❌ Runtime JSON file not found: $json"
  exit 10
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required to validate $json"
  exit 12
fi

echo "dotnet: $(command -v dotnet && dotnet --version || echo 'not installed')"
echo "node: $(command -v node && node --version || echo 'not installed')"

jq -e '.dotnet.version? and .node.version?' "$json" >/dev/null || { echo "runtime json missing fields"; exit 11; }

# Emit JSON markers for log harvesting
echo "PDS_RUNTIME_JSON_START"
cat "$json"
echo "PDS_RUNTIME_JSON_END"

echo "Smoke test completed successfully."