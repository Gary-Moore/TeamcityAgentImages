ARG teamCityAgentImage=jetbrains/teamcity-agent:2024.07.3-linux-sudo
FROM ${teamCityAgentImage}

USER root
WORKDIR /opt/buildagent/work

# Fetch the latest .NET SDK dynamically
ARG dotnetSdkVersion=8.0

RUN apt-get update && apt-get install -y --no-install-recommends wget jq curl && \
    METADATA_URL="https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/8.0/releases.json" && \
    echo "Fetching .NET SDK metadata from $METADATA_URL..." && \
    curl -s $METADATA_URL | jq '.' && \
    LATEST_SDK=$(curl -s $METADATA_URL | jq -r '.latestSDK') && \
    echo "✅ Latest .NET SDK version: $LATEST_SDK" && \
    echo "Fetching SDK details for version: $LATEST_SDK..." && \
    curl -s $METADATA_URL | jq -r --arg SDK "$LATEST_SDK" \
    '.releases[] | select(.sdk.version==$SDK) | .sdk.files[] | .name' && \
    DOWNLOAD_URL=$(curl -s $METADATA_URL | jq -r --arg SDK "$LATEST_SDK" \
    '.releases[] | select(.sdk.version==$SDK) | .sdk.files[] | select(.rid=="linux-x64" and .name=="dotnet-sdk-linux-x64.tar.gz") | .url') && \
    echo "✅ Extracted Download URL: $DOWNLOAD_URL" && \
    if [ -z "$DOWNLOAD_URL" ]; then echo "❌ ERROR: Failed to fetch .NET SDK download URL!" && exit 1; fi && \
    echo "Downloading .NET SDK from $DOWNLOAD_URL" && \
    wget -O /tmp/dotnet.tar.gz "$DOWNLOAD_URL" && \
    mkdir -p /opt/dotnet && \
    tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet && \
    ln -sf /opt/dotnet/dotnet /usr/bin/dotnet && \
    rm -rf /tmp/dotnet.tar.gz


# Add buildagent user to Docker group
RUN usermod -aG docker buildagent

# Run verification steps for .NET installation
RUN dotnet help && dotnet --info

VOLUME /var/lib/docker
USER buildagent
