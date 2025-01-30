ARG teamCityAgentImage=jetbrains/teamcity-agent:2024.07.3-linux-sudo

FROM ${teamCityAgentImage}

ARG dotnetSdkVersion=8.0
ARG nodeVersion=22

USER root
WORKDIR /opt/buildagent/work

# install the dotnet SDK
RUN rm -rf /usr/share/dotnet && \
    apt-get update && apt-get install -y --no-install-recommends wget jq curl && \
    METADATA_URL="https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${dotnetSdkVersion}/releases.json" && \
    echo "Fetching .NET SDK metadata from $METADATA_URL..." && \
    LATEST_SDK=$(curl -s $METADATA_URL | jq -r 'if .["latest-sdk"] then .["latest-sdk"] else "" end') && \
    echo "✅ Latest .NET SDK version: $LATEST_SDK" && \
    DOWNLOAD_URL=$(curl -s $METADATA_URL | jq -r --arg SDK "$LATEST_SDK" \
    '.releases[] | select(.sdk.version==$SDK) | .sdk.files[] | select(.rid=="linux-x64" and .name=="dotnet-sdk-linux-x64.tar.gz") | .url') && \
    echo "✅ Extracted Download URL: $DOWNLOAD_URL" && \
    if [ -z "$DOWNLOAD_URL" ]; then echo "❌ ERROR: Failed to fetch .NET SDK download URL!" && exit 1; fi && \
    echo "Downloading .NET SDK from $DOWNLOAD_URL" && \
    wget -O /tmp/dotnet.tar.gz "$DOWNLOAD_URL" && \
    mkdir -p /opt/dotnet && \
    tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet && \
    ln -sf /opt/dotnet/dotnet /usr/bin/dotnet && \
    rm -rf /tmp/dotnet.tar.gz && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    usermod -aG docker buildagent && \
    dotnet help && dotnet --info

# Set default shell to bash
SHELL ["/bin/bash", "-c"]

RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /usr/local/bin --skip-shell

ENV PATH="/root/.fnm:$PATH"
ENV FNM_DIR="/root/.fnm"

RUN echo 'export PATH="$FNM_DIR:$PATH"' | tee -a /etc/profile.d/fnm.sh /etc/profile && \
    echo 'eval "$(fnm env --shell bash)"' | tee -a /etc/profile.d/fnm.sh /etc/profile && \
    chmod +x /etc/profile.d/fnm.sh

# Set default Node.js version and install npm globally
RUN source /etc/profile.d/fnm.sh && \
    fnm install 18 && fnm use 18 && fnm default 18 && \
    npm install -g npm

# Ensure the TeamCity agent user has access
RUN mkdir -p /home/buildagent/.fnm && chown -R buildagent:buildagent /home/buildagent/.fnm

VOLUME /var/lib/docker
USER buildagent


