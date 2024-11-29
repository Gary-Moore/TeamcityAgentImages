# Use official Teamcity agent image
FROM jetbrains/teamcity-agent:2024.07.3-linux-sudo

# Switch to root user
USER root

# Set the working directory
WORKDIR /build

# api-get update: Updates the list of available packages from repositories before installing new packages.
# apt-get install -y wget: Install the yget utility, a CLI tool for downloading files, this will allow the .NET SDK to be downloaded. 
# wget https://download.visualstudio.microsoft.com/download/pr/.../dotnet-sdk-....tar.gz: Downlaods a specific version of .NET SDK from the Microsoft download site.
# mkdir -p /usr/share/dotnet: creates a directory /usr/share/dotnet if it doesn't exist. This will store the extracted contents of the dotnet SDK.
#        -p: Ensures it does not fail if directory exists
# tar zxf dotnet-sdk-.....tar.gz -C /usr/share/dotnet: Extracts the contents of the tar file into the /usr/share/dotnet directory;
#        z: Tell tar that the file is compressed with gzip.
#        x: Tell tar to extract the files.
#        f: Specifies file to extract (dotnet-sdk-....tar.gz).
#        -C: /user/share/dotnet: Extracts contents to /usr/share/dotnet directory.
# ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet: Creates a symbolic link (a shortcut) to the dotnet executable inside /usr/bin/dotnet; dotnet command is accessible by adding it to the system's PATH.
#       in: This command creates a link.
#       -s: Specifies the link is symbolic.
#rm dotnet-sdk-.....tar.gz: Delete the dotnet archive file, cleaning up after the installation.
RUN apt-get update && apt-get install -y \
    wget \
    && wget https://download.visualstudio.microsoft.com/download/pr/4e3b04aa-c015-4e06-a42e-05f9f3c54ed2/74d1bb68e330eea13ecfc47f7cf9aeb7/dotnet-sdk-8.0.404-linux-x64.tar.gz \
    && mkdir -p /usr/share/dotnet \
    && tar zxf dotnet-sdk-8.0.404-linux-x64.tar.gz -C /usr/share/dotnet \
    && ln -s /usr/share/dotnet/dotnet \
    && rm dotnet-sdk-8.0.404-linux-x64.tar.gz

# Set environment variables
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="$PATH:/usr/share/dotnet"
ENV HOME=/root

# Configure TeamCity agent properties
RUN echo "docker.server.osType=linux" >> /opt/teamcity-agent/conf/buildAgent.properties \
    && echo "env.HOME=/root" >> /opt/teamcity-agent/conf/buildAgent.properties \
    && echo "DotNetCLI_Path=/usr/bin/dotnet" >> /opt/teamcity-agent/conf/buildAgent.properties

# Ensure agent can register with the TeamCity server (run agent on container startup)
CMD ["/opt/teamcity-agent/bin/agent.sh", "run"]