# Use official TeamCity agent image
ARG teamCityAgentImage=jetbrains/teamcity-agent:2024.07.3-linux-sudo
FROM ${teamCityAgentImage}

# Switch to root user
USER root

# Set the working directory to align with TeamCity standards
WORKDIR /opt/buildagent/work

# Arguments for .NET SDK customization
ARG dotnetSdkVersion=8.0.404
ARG dotnetSdkChecksum
ENV DOTNET_DOWNLOAD_URL="https://download.visualstudio.microsoft.com/download/pr/4e3b04aa-c015-4e06-a42e-05f9f3c54ed2/74d1bb68e330eea13ecfc47f7cf9aeb7/dotnet-sdk-${dotnetSdkVersion}-linux-x64.tar.gz"

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    && echo "Downloading .NET SDK [${dotnetSdkVersion}] from $DOTNET_DOWNLOAD_URL ..." \
    && wget -O /tmp/dotnet.tar.gz $DOTNET_DOWNLOAD_URL \
    && echo "Verifying checksum..." \
    && sha512sum /tmp/dotnet.tar.gz \
    && echo "${dotnetSdkChecksum}  /tmp/dotnet.tar.gz" | sha512sum -c - || exit 1 \
    && mkdir -p /opt/dotnet \
    && tar -zxf /tmp/dotnet.tar.gz -C /opt/dotnet \
    && ln -s /opt/dotnet/dotnet /usr/bin/dotnet \
    && rm -rf /tmp/dotnet.tar.gz \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && find /opt/dotnet -name "*.lzma" -type f -delete

# Add buildagent user to Docker group
RUN usermod -aG docker buildagent

# Verify .NET installation
RUN dotnet --info

# Expose Docker socket volume
VOLUME /var/lib/docker

# Switch back to the buildagent user
USER buildagent
