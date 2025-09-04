# --------------------------------------------
# TeamCity Azure CLI Agent (ACI-ready) + CA trust
# Server 2025.07
# --------------------------------------------

ARG BASE_IMAGE="jetbrains/teamcity-agent:2025.07-linux-sudo"
FROM ${BASE_IMAGE}

# ---- Build args ----
ARG VCS_REF
ARG BUILD_DATE

# CA download + pinning (pass via --build-arg)
ARG ENTRUST_INTERMEDIATE_URL        # e.g. https://.../Entrust_OV_TLS_Issuing_RSA_CA_2.crt
ARG ENTRUST_INTERMEDIATE_SHA256     # 64-hex chars
ARG ENTRUST_ALIAS="entrust-ov-tls-issuing-rsa-ca-2"

USER root
WORKDIR /opt/buildagent/work
SHELL ["/bin/bash", "-c"]

# ---- OS prep (tools + CA bundles) ----
RUN set -euxo pipefail \
  && apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y --no-install-recommends \
       curl wget jq gnupg openssl ca-certificates ca-certificates-java \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

  # Make sure the agent uses the patched JRE (define early so we can reuse it below)
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"
ENV AZURE_CORE_COLLECT_TELEMETRY=0

# ---- Import Entrust intermediate into JRE cacerts (HTTP-only, hash-pinned) ----
RUN set -euxo pipefail \
  && : "${ENTRUST_INTERMEDIATE_URL:?missing}" \
  && : "${ENTRUST_INTERMEDIATE_SHA256:?missing}" \
  && KEYTOOL="${JAVA_HOME}/bin/keytool" \
  && STOREPASS=changeit \
  && TMP_CRT=/tmp/entrust-ov.crt \
  && TMP_PEM=/tmp/entrust-ov.pem \
  # Strictly use the URL as provided (HTTP allowed)
  && curl -fsSL --retry 3 --retry-connrefused "${ENTRUST_INTERMEDIATE_URL}" -o "${TMP_CRT}" \  
  # Hash pin the download
  && echo "${ENTRUST_INTERMEDIATE_SHA256}  ${TMP_CRT}" | sha256sum -c - \
  # Convert to PEM if input was DER; otherwise reuse as-is
  && if openssl x509 -in "${TMP_CRT}" -inform DER -out "${TMP_PEM}" -outform PEM 2>/dev/null; then :; else cp "${TMP_CRT}" "${TMP_PEM}"; fi \  
  # Verify fingerprint again on the PEM we’ll import
  && ACTUAL_FP="$(openssl x509 -in "${TMP_PEM}" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')" \
  && echo "Expected FP: ${ENTRUST_INTERMEDIATE_SHA256}" \
  && echo "Actual FP:   ${ACTUAL_FP}" \
  && [ "${ACTUAL_FP}" = "${ENTRUST_INTERMEDIATE_SHA256}" ] \
  # Idempotent import
  && "${KEYTOOL}" -cacerts -storepass "${STOREPASS}" -delete -alias "${ENTRUST_ALIAS}" >/dev/null 2>&1 || true \
  && "${KEYTOOL}" -importcert -trustcacerts -noprompt \
       -alias "${ENTRUST_ALIAS}" \
       -file "${TMP_PEM}" \
       -cacerts -storepass "${STOREPASS}" \
  # Clean
  && rm -f "${TMP_CRT}" "${TMP_PEM}" \
  && rm -rf /var/lib/apt/lists/*

# ---- Azure CLI ----
# Installs only the Azure CLI (no SDKs), from Microsoft's official repo.
RUN set -euxo pipefail \
  && export DEBIAN_FRONTEND=noninteractive \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
     | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg \
  && chmod 0644 /etc/apt/keyrings/microsoft.gpg \
  && . /etc/os-release \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${VERSION_CODENAME} main" \
     > /etc/apt/sources.list.d/azure-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends azure-cli \
  && az version || true \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

LABEL org.opencontainers.image.title="GammaWeb TeamCity Linux Dotnet Agent" \
      org.opencontainers.image.source="https://github.com/Gary-Moore/TeamcityAgentImages" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# Copy smoke test into the image and make it executable
ENV ENTRUST_ALIAS="${ENTRUST_ALIAS}"
COPY docker/linux/az-agent/test-image.sh /usr/local/bin/test-image.sh
RUN chmod +x /usr/local/bin/test-image.sh

USER buildagent
WORKDIR /home/buildagent
