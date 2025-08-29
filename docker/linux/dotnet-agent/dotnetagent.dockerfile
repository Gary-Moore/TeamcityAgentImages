# --------------------------------------------
# TeamCity DotNet Agent (ACI-ready) + CA trust
# Server 2025.07
# --------------------------------------------

ARG BASE_IMAGE="jetbrains/teamcity-agent:2025.07-linux-sudo"
FROM ${BASE_IMAGE}

# ---- Build args ----
ARG dotnetSdkVersion=8.0
ARG nodeVersion=20

ARG VCS_REF
ARG BUILD_DATE

# CA download + pinning (pass via --build-arg)
ARG ENTRUST_INTERMEDIATE_URL       # e.g. https://.../Entrust_OV_TLS_Issuing_RSA_CA_2.crt
ARG ENTRUST_INTERMEDIATE_SHA256    # 64-hex chars

ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    NUGET_XMLDOC_MODE=skip \
    POWERSHELL_TELEMETRY_OPTOUT=1

USER root
WORKDIR /opt/buildagent/work
SHELL ["/bin/bash", "-c"]

# ---- OS prep (tools + CA bundles) ----
RUN set -euxo pipefail \
  && apt-get update \
  && apt-get -y upgrade \
  && apt-get install -y --no-install-recommends \
       curl wget jq openssl ca-certificates ca-certificates-java \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN set -euxo pipefail \
  # Fetch Entrust OV intermediate + pin
  && test -n "${ENTRUST_INTERMEDIATE_URL}" \
  && test -n "${ENTRUST_INTERMEDIATE_SHA256}" \
  && curl -fsSL "${ENTRUST_INTERMEDIATE_URL}" -o /tmp/entrust-ov.crt \
  && echo "${ENTRUST_INTERMEDIATE_SHA256}  /tmp/entrust-ov.crt" | sha256sum -c - \
  && openssl x509 -in /tmp/entrust-ov.crt -inform DER -out /tmp/entrust-ov.pem -outform PEM || cp /tmp/entrust-ov.crt /tmp/entrust-ov.pem \
  && ACTUAL_FP=$(openssl x509 -in /tmp/entrust-ov.pem -noout -fingerprint -sha256 | cut -d= -f2 | tr -d ':') \
  && echo "Expected FP: ${ENTRUST_INTERMEDIATE_SHA256}" \
  && echo "Actual FP: ${ACTUAL_FP}" \
  && [ "${ACTUAL_FP}" = "${ENTRUST_INTERMEDIATE_SHA256}" ] \
  \
  # Import into Corretto (used by the agent)
  && KEYTOOL=/opt/java/openjdk/bin/keytool \
  && STOREPASS=changeit \
  && "$KEYTOOL" -importcert -trustcacerts -noprompt \
       -alias entrust-ov-tls-issuing-rsa-ca-2 \
       -file /tmp/entrust-ov.pem \
       -cacerts -storepass "$STOREPASS" \
  && rm -f /tmp/entrust-ov.* /tmp/sectigo-r46.* \
  && rm -rf /var/lib/apt/lists/*

# ---- PowerShell (pwsh) ----
RUN set -euxo pipefail \
  && . /etc/os-release \
  && curl -fsSL "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" \
    -o /tmp/packages-microsoft-prod.deb \
  && dpkg -i /tmp/packages-microsoft-prod.deb \
  && rm -f /tmp/packages-microsoft-prod.deb \
  && apt-get update \
  && apt-get install -y --no-install-recommends powershell \
  && pwsh -NoLogo -NoProfile -Command '$PSVersionTable' \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- .NET SDK (latest in given major) ----
RUN set -euxo pipefail \
  && rm -rf /usr/share/dotnet \
  && METADATA_URL="https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${dotnetSdkVersion}/releases.json" \
  && METADATA="$(curl -fsSL "$METADATA_URL")" \
  && LATEST_SDK="$(echo "$METADATA" | jq -r '."latest-sdk" // empty')" \
  && [ -n "$LATEST_SDK" ] \
  && DOWNLOAD_URL="$(echo "$METADATA" | jq -r --arg SDK "$LATEST_SDK" \
        '.releases[] | select(.sdk.version==$SDK) | .sdk.files[] \
         | select(.rid=="linux-x64" and .name=="dotnet-sdk-linux-x64.tar.gz") | .url')" \
  && [ -n "$DOWNLOAD_URL" ] \
  && wget -qO /tmp/dotnet.tar.gz "$DOWNLOAD_URL" \
  && mkdir -p /opt/dotnet \
  && tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet \
  && ln -sf /opt/dotnet/dotnet /usr/bin/dotnet \
  && rm -f /tmp/dotnet.tar.gz \
  && dotnet --info

# ---- Node via FNM ----
RUN set -euxo pipefail \
  && curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /usr/local/bin --skip-shell \
  && echo 'export PATH="/home/buildagent/.fnm:$PATH:/usr/local/bin"' | tee -a /etc/profile.d/fnm.sh /etc/profile \
  && echo 'eval "$(fnm env --shell bash)"' | tee -a /etc/profile.d/fnm.sh /etc/profile \
  && chmod +x /etc/profile.d/fnm.sh

USER buildagent
WORKDIR /home/buildagent
RUN set -euxo pipefail \
  && mkdir -p /home/buildagent/.fnm \
  && source /etc/profile.d/fnm.sh \
  && fnm install ${nodeVersion} \
  && fnm use ${nodeVersion} \
  && fnm default ${nodeVersion} \
  && echo 'source /etc/profile.d/fnm.sh' >> ~/.bashrc \
  && echo 'source /etc/profile.d/fnm.sh' >> ~/.profile

USER root
RUN ln -sf /home/buildagent/.fnm/aliases/default/bin/node /usr/local/bin/node \
 && ln -sf /home/buildagent/.fnm/aliases/default/bin/npm  /usr/local/bin/npm

# Make sure the agent uses the patched JRE
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

LABEL org.opencontainers.image.title="GammaWeb TeamCity Linux Dotnet Agent" \
      org.opencontainers.image.source="https://github.com/Gary-Moore/TeamcityAgentImages" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# Copy smoke test into the image and make it executable
COPY docker/linux/dotnet-agent/test-image.sh /usr/local/bin/test-image.sh
RUN chmod +x /usr/local/bin/test-image.sh

VOLUME /var/lib/docker
USER buildagent
WORKDIR /home/buildagent
