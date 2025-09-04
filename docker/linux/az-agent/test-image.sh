#!/usr/bin/env bash
set -euo pipefail

# -------- config flags --------
REQUIRE_AZ="${REQUIRE_AZ:-1}"     # 1 = az must be present; 0 = az optional
REQUIRE_JAVA="${REQUIRE_JAVA:-1}" # 1 = java must be present; 0 = optional

# The alias we import in the Dockerfile
ENTRUST_ALIAS="${ENTRUST_ALIAS:-entrust-ov-tls-issuing-rsa-ca-2}"
KEYTOOL="${KEYTOOL:-/opt/java/openjdk/bin/keytool}"
STOREPASS="${STOREPASS:-changeit}"

have() { command -v "$1" >/dev/null 2>&1; }
getver() { "$1" --version 2>&1 | head -n1 || true; }

fail() { echo "❌ $*" >&2; exit 1; }

echo "=== smoke: whoami/id ==="
WHO="$(whoami || true)"; echo "whoami: ${WHO:-n/a}"
id || true

echo "=== smoke: PATH ==="
echo "$PATH"

echo "=== smoke: required files ==="
test -x /usr/local/bin/entrypoint-wrapper.sh || fail "entrypoint-wrapper.sh missing or not executable"

# ---- Java & Entrust CA check ----
JAVA_VER=""
if have java; then
  JAVA_VER="$(java -version 2>&1 | head -n1 | sed 's/^/java: /')"
  echo "$JAVA_VER"
else
  [[ "$REQUIRE_JAVA" = "1" ]] && fail "Java runtime not found on PATH"
  echo "java: not installed (allowed)"
fi

# Verify the Entrust intermediate is actually in cacerts
if [[ -x "$KEYTOOL" ]]; then
  if "$KEYTOOL" -cacerts -storepass "$STOREPASS" -list -alias "$ENTRUST_ALIAS" >/dev/null 2>&1; then
    echo "entrust: alias '$ENTRUST_ALIAS' present in cacerts ✅"
    ENTRUST_OK=1
  else
    echo "entrust: alias '$ENTRUST_ALIAS' NOT found in cacerts ❌"
    ENTRUST_OK=0
  fi
else
  echo "entrust: keytool not found at $KEYTOOL (skipping check)"
  ENTRUST_OK=0
fi

# ---- Azure CLI check ----
AZ_PRESENT=0
AZ_VER_STR=""
if have az; then
  AZ_PRESENT=1
  if have jq; then
    AZ_VER_STR="$(az version -o json 2>/dev/null | jq -r '.["azure-cli"] // empty')"
  fi
  [[ -z "$AZ_VER_STR" ]] && AZ_VER_STR="$(az version 2>/dev/null | head -n1 | sed 's/^/azure-cli: /' || true)"
  [[ -z "$AZ_VER_STR" ]] && AZ_VER_STR="azure-cli: installed"
  echo "$AZ_VER_STR"
else
  [[ "$REQUIRE_AZ" = "1" ]] && fail "Azure CLI not found on PATH"
  echo "azure-cli: not installed (allowed)"
fi

# ---- Optional tooling checks (non-fatal) ----
if have dotnet; then
  echo "dotnet: $(dotnet --info 2>/dev/null | head -n1)"
else
  echo "dotnet: not installed (ok for some variants)"
fi

if have node; then
  echo "node: $(node --version 2>/dev/null)"
else
  echo "node: not installed (ok for some variants)"
fi

# Summarise + JSON for outer scraper
SMOKE_TS="$(date -u +%FT%TZ)"
echo "=== smoke: success @ ${SMOKE_TS} ==="

# Single-line JSON (your wrapper script supports this already)
echo "PDS_RUNTIME_JSON: {\"smoke\":\"ok\",\"user\":\"${WHO:-unknown}\",\"entrustOk\":${ENTRUST_OK},\"azPresent\":${AZ_PRESENT},\"java\":\"${JAVA_VER//\"/\\\"}\",\"az\":\"${AZ_VER_STR//\"/\\\"}\",\"ts\":\"${SMOKE_TS}\"}"
