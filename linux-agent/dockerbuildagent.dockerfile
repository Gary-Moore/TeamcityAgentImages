# --------------------------------------------
# TeamCity Docker Build Agent Dockerfile
# --------------------------------------------

# Use official TeamCity base image
ARG BASE_IMAGE="jetbrains/teamcity-agent:2025.03-linux-sudo"
FROM $BASE_IMAGE

# Set required Docker CLI version (optional override)
ARG dockerVersion=25.0.5

USER root
WORKDIR /opt/buildagent/work

# OS-level security patching, install dependencies, and clean up
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean

# Add Azure CLI install
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    az version