# --------------------------------------------
# TeamCity Docker Build Agent Dockerfile
# --------------------------------------------

# Use official TeamCity base image
ARG BASE_IMAGE="jetbrains/teamcity-agent:2025.03-linux-sudo"
FROM $BASE_IMAGE

# Set required Docker CLI version (optional override)
ARG dockerVersion=28.2.2

USER root
WORKDIR /opt/buildagent/work

# OS patching + install curl (used in later steps)
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    az version

# Add Docker CLI (client only)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli=${dockerVersion}~* && \
    docker --version && \
    rm -rf /var/lib/apt/lists/*
