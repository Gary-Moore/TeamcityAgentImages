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


# Install fnm (Fast Node Manager) manually
# Install fnm (Fast Node Manager) and manually configure shell
RUN curl -fsSL https://fnm.vercel.app/install | bash && \
    export FNM_DIR="/home/buildagent/.fnm" && \
    mkdir -p /home/buildagent/.config/fnm && \
    echo "export FNM_DIR=\"/home/buildagent/.fnm\"" >> /home/buildagent/.bashrc && \
    echo "eval \"\$(fnm env --shell=bash)\"" >> /home/buildagent/.bashrc && \
    echo "export PATH=\"$FNM_DIR:$PATH\"" | tee -a /etc/profile /home/buildagent/.bashrc > /dev/null && \
    chmod +x /home/buildagent/.fnm/fnm && \
    echo "✅ fnm installed successfully"

# Ensure fnm is globally available in all shells
RUN echo "export PATH=\"/home/buildagent/.fnm/bin:\$PATH\"" | tee -a /etc/profile /etc/bash.bashrc > /dev/null && \
    echo "eval \"\$(fnm env --shell=bash)\"" | tee -a /etc/profile /etc/bash.bashrc > /dev/null && \
    chmod +x /home/buildagent/.fnm/bin/fnm && \
    echo "✅ fnm environment configured globally"

# Set default shell to bash
SHELL ["/bin/bash", "-c"]

# Install Node.js using fnm and persist globally
RUN source /etc/profile && \
    fnm install $nodeVersion && \
    fnm use $nodeVersion && \
    fnm default $nodeVersion && \
    export NODE_PATH="$(fnm exec -- node -p 'process.execPath')" && \
    export NPM_DIR="$(fnm exec -- npm -g bin)" && \
    export NPX_PATH="$NPM_DIR/npx" && \
    ln -sf "$NODE_PATH" /usr/bin/node && \
    ln -sf "$NPM_DIR/npm" /usr/bin/npm && \
    ln -sf "$NPX_PATH" /usr/bin/npx && \
    echo "✅ Installed Node.js version:" && node -v && \
    echo "✅ Installed npm version:" && npm -v

VOLUME /var/lib/docker
USER buildagent
