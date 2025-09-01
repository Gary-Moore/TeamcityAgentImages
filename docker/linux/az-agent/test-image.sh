#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# Basic presence checks
if ! have az; then
  echo "❌ Azure CLI not found on PATH"
  exit 20
fi

# Show versions (robust to missing jq)
if have jq; then
  AZ_VER="$(az version --output json 2>/dev/null | jq -r '.["azure-cli"] // empty')"
  [[ -n "$AZ_VER" ]] || AZ_VER="$(az version 2>/dev/null | head -n1 || echo 'installed')"
else
  AZ_VER="$(az version 2>/dev/null | head -n1 || echo 'installed')"
fi

echo "az: ${AZ_VER}"

# Success
echo "Smoke test completed successfully."
