#!/usr/bin/env bash

set -euo pipefail

json="opt/pds-runtime.json"
[[ -f "$json" ]] || { echo "❌ JSON file not found: $json"; exit 10; }

# Basic checks
echo "dotnet: $(dotnet --version)"
echo "node: $(node --version)"
jq -e '.dotnet.version and .node.version' "$json" >dev/null