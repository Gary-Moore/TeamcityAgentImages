# Use official TeamCity agent image
ARG teamCityAgentImage=jetbrains/teamcity-agent:2024.07.3-linux-sudo
FROM ${teamCityAgentImage}

USER root
WORKDIR /opt/buildagent/work

ARG dotnetSdkVersion=8.0.404
ENV DOTNET_DOWNLOAD_URL="https://download.visualstudio.microsoft.com/download/pr/4e3b04aa-c015-4e06-a42e-05f9f3c54ed2/74d1bb68e330eea13ecfc47f7cf9aeb7/dotnet-sdk-${dotnetSdkVersion}-linux-x64.tar.gz"

RUN apt-get update && apt-get install -y --no-install-recommends wget

# Download and install .NET SDK
RUN echo "Downloading .NET SDK [${dotnetSdkVersion}] from $DOTNET_DOWNLOAD_URL ..." \
    && wget -O /tmp/dotnet.tar.gz $DOTNET_DOWNLOAD_URL \
    && mkdir -p /opt/dotnet \
    && tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet \
    && ln -sf /opt/dotnet/dotnet /usr/bin/dotnet \  # Use '-sf' to overwrite if link exists
    && rm -rf /tmp/dotnet.tar.gz \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && find /opt/dotnet -name "*.lzma" -type f -delete

# Verify .NET installation
RUN dotnet --info

USER buildagent
