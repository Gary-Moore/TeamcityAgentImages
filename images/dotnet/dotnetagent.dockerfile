# Use official TeamCity agent image
ARG teamCityAgentImage=jetbrains/teamcity-agent:2024.07.3-linux-sudo
FROM ${teamCityAgentImage}

USER root
WORKDIR /opt/buildagent/work

# Fetch the latest .NET SDK dynamically
ARG dotnetSdkVersion=8.0

RUN apt-get update && apt-get install -y --no-install-recommends wget jq

# Remove existing .NET SDKs
RUN rm -rf /usr/share/dotnet

# Download and install .NET SDK

RUN METADATA_URL="https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/$dotnetSdkVersion/releases.json" && \
    LATEST_SDK=$(curl -s $METADATA_URL | jq -r '.latestSDK') && \
    DOWNLOAD_URL=$(curl -s $METADATA_URL | jq -r --arg SDK "$LATEST_SDK" '.releases[] | select(.sdk.version==$SDK) | .sdk.files[] | select(.name=="dotnet-sdk-linux-x64.tar.gz") | .url') && \
    echo "Downloading .NET SDK from $DOWNLOAD_URL" \
    && wget -O /tmp/dotnet.tar.gz "$DOWNLOAD_URL" \
    && mkdir -p /opt/dotnet \
    && tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet \
    && ln -sf /opt/dotnet/dotnet /usr/bin/dotnet \
    && rm -rf /tmp/dotnet.tar.gz \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && find /opt/dotnet -name "*.lzma" -type f -delete

# Verify .NET installation
RUN dotnet --info

USER buildagent
