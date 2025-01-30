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

# Switch to buildagent user for Node.js installation
USER buildagent
WORKDIR /home/buildagent

# Install fnm (Fast Node Manager) and manually configure shell
# Install fnm manually (without the auto-installer)
RUN mkdir -p /home/buildagent/.fnm/bin && \
    curl -fsSL https://github.com/Schniz/fnm/releases/latest/download/fnm-linux.zip -o /tmp/fnm.zip && \
    unzip /tmp/fnm.zip -d /home/buildagent/.fnm/bin && \
    rm -rf /tmp/fnm.zip && \
    chmod +x /home/buildagent/.fnm/bin/fnm && \
    ln -sf /home/buildagent/.fnm/bin/fnm /usr/local/bin/fnm && \
    echo "✅ fnm installed manually"

# Ensure fnm is globally available
ENV PATH="/home/buildagent/.fnm/bin:$PATH"

# Install Node.js using fnm
RUN fnm install $nodeVersion && \
    fnm use $nodeVersion && \
    fnm default $nodeVersion && \
    echo "✅ Installed Node.js version:" && node -v && \
    echo "✅ Installed npm version:" && npm -v

VOLUME /var/lib/docker
