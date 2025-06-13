# --------------------------------------------
# TeamCity OpenTofu Agent Dockerfile
# --------------------------------------------

# Use official TeamCity base image
ARG BASE_IMAGE="jetbrains/teamcity-agent:2025.03-linux-sudo"
FROM $BASE_IMAGE

# Set required Terraform version (can be passed in at build time)
ARG tofuVersion=1.9.5

# Switch to root user to install dependencies
USER root
WORKDIR /opt/buildagent/work
    
# OS-level security patching, install dependencies, and clean up
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends wget jq curl && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean