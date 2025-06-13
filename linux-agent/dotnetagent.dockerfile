# --------------------------------------------
# TeamCity DotNet Agent Dockerfile Template
# --------------------------------------------

# Default base image (can be overridden at build time)
ARG BASE_IMAGE="jetbrains/teamcity-agent:2025.03-linux-sudo"
FROM $BASE_IMAGE

# Arguments for .NET SDK and Node.js versions
ARG dotnetSdkVersion=8.0
ARG nodeVersion=20

# Switch to root user to install dependencies
USER root
WORKDIR /opt/buildagent/work
    
# OS-level security patching, install dependencies, and clean up
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends wget jq curl && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Dynamically install specified .NET SDK version
RUN rm -rf /usr/share/dotnet && \
    METADATA_URL="https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${dotnetSdkVersion}/releases.json" && \
    echo "Fetching .NET SDK metadata from: $METADATA_URL" && \
    METADATA=$(curl -s $METADATA_URL) && \
    LATEST_SDK=$(echo "$METADATA" | jq -r 'if .["latest-sdk"] then .["latest-sdk"] else "" end') && \
    echo "Latest .NET SDK version detected: $LATEST_SDK" && \
    DOWNLOAD_URL=$(echo "$METADATA" | jq -r --arg SDK "$LATEST_SDK" \
        '.releases[] | select(.sdk.version==$SDK) | .sdk.files[] | select(.rid=="linux-x64" and .name=="dotnet-sdk-linux-x64.tar.gz") | .url') && \
    echo "SDK download URL: $DOWNLOAD_URL" && \
    if [ -z "$DOWNLOAD_URL" ]; then echo "❌ ERROR: Failed to resolve .NET SDK download URL"; exit 1; fi && \
    wget -O /tmp/dotnet.tar.gz "$DOWNLOAD_URL" && \
    mkdir -p /opt/dotnet && \
    tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet && \
    ln -sf /opt/dotnet/dotnet /usr/bin/dotnet && \
    rm -rf /tmp/dotnet.tar.gz && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    usermod -aG docker buildagent && \
    dotnet --info

# Use bash as default shell for the agent
SHELL ["/bin/bash", "-c"]
    
# Install and configure FNM (Node version manager)
RUN curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /usr/local/bin --skip-shell && \
    echo 'export PATH="/home/buildagent/.fnm:$PATH:/usr/local/bin"' | tee -a /etc/profile.d/fnm.sh /etc/profile && \
    echo 'eval "$(fnm env --shell bash)"' | tee -a /etc/profile.d/fnm.sh /etc/profile && \
    echo 'eval "$(fnm env)"' >> /home/buildagent/.bashrc && \
    echo 'eval "$(fnm env)"' >> /home/buildagent/.profile && \
    chmod +x /etc/profile.d/fnm.sh
    
# Switch to buildagent user and install Node.js
USER buildagent
WORKDIR /home/buildagent

# Setup FN and install Node.js
RUN mkdir -p /home/buildagent/.fnm && \
    chown -R buildagent:buildagent /home/buildagent/.fnm && \
    bash -c "source /etc/profile.d/fnm.sh && fnm install $nodeVersion && fnm use $nodeVersion && fnm default $nodeVersion" && \
    echo 'source /etc/profile.d/fnm.sh' >> ~/.bashrc && \
    echo '. /etc/profile.d/fnm.sh' >> ~/.profile && \
    echo 'source /etc/profile.d/fnm.sh' >> ~/.shrc && \
    echo 'source /etc/profile.d/fnm.sh' >> ~/.bash_profile

# Switch to root user to create symbolic links
USER root


# Create symbolic links for node and npm
RUN ln -sf /home/buildagent/.fnm/aliases/default/bin/node /usr/local/bin/node && \
    ln -sf /home/buildagent/.fnm/aliases/default/bin/npm /usr/local/bin/npm

VOLUME /var/lib/docker

USER buildagent