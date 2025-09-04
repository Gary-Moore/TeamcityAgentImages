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

# ---- Import Entrust intermediate into JRE cacerts (idempotent) ----
RUN set -euxo pipefail \
  && : "${ENTRUST_INTERMEDIATE_URL:?missing}" \
  && : "${ENTRUST_INTERMEDIATE_SHA256:?missing}" \
  # Prefer HTTPS for transport (you still hash-pin it)
  && case "${ENTRUST_INTERMEDIATE_URL}" in http://*) \
       echo "WARN: ENTRUST_INTERMEDIATE_URL is http:// — switching to https:// if possible"; \
       ENTRUST_INTERMEDIATE_URL="${ENTRUST_INTERMEDIATE_URL/http:\/\//https:\/\/}"; \
     esac \
  && curl -fsSL "${ENTRUST_INTERMEDIATE_URL}" -o /tmp/entrust-ov.crt \
  && echo "${ENTRUST_INTERMEDIATE_SHA256}  /tmp/entrust-ov.crt" | sha256sum -c - \
  && openssl x509 -in /tmp/entrust-ov.crt -inform DER -out /tmp/entrust-ov.pem -outform PEM || cp /tmp/entrust-ov.crt /tmp/entrust-ov.pem \
  && ACTUAL_FP="$(openssl x509 -in /tmp/entrust-ov.pem -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':')" \
  && echo "Expected FP: ${ENTRUST_INTERMEDIATE_SHA256}" \
  && echo "Actual FP:   ${ACTUAL_FP}" \
  && [ "${ACTUAL_FP}" = "${ENTRUST_INTERMEDIATE_SHA256}" ] \
  # Idempotent import: delete alias if it already exists, then import
  && KEYTOOL="${JAVA_HOME}/bin/keytool" \
  && STOREPASS=changeit \
  && "${KEYTOOL}" -cacerts -storepass "${STOREPASS}" -delete -alias "${ENTRUST_ALIAS}" >/dev/null 2>&1 || true \
  && "${KEYTOOL}" -importcert -trustcacerts -noprompt \
       -alias "${ENTRUST_ALIAS}" \
       -file /tmp/entrust-ov.pem \
       -cacerts -storepass "${STOREPASS}" \
  && rm -f /tmp/entrust-ov.* /tmp/sectigo-r46.* \
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
