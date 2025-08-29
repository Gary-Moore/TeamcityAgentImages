#!/usr/bin/env bash

set -euo pipefail

json="opt/pds-runtime.json"
[[ -f "$json" ]] || { echo "❌ JSON file not found: $json"; exit 10; }

# Basic checks
echo "dotnet: $(command -v dotnet && dotnet --version || echo 'not installed')"
echo "node: $(command -v node && node --version || echo 'not installed')"

if command -v jq > /dev/null 2>&1; then
  jq -e '.dotnet.version? and .node.version?' "$json" >dev/null || { echo "runtime json missing fields"; exit 11; }
fi

echo "PSD_RUNTIME_JSON_START"
cat "$json"
echo "PSD_RUNTIME_JSON_END"

echo "Smoke test completed successfully."