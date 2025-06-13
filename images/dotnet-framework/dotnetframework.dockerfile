FROM jetbrains/jetbrains/teamcity-agent:2024.07-windowsservercore

# Install Chocolatey for package management
RUN @powershell -NoProfile -ExecutionPolicy Bypass -Command `
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) `
    && choco feature enable -n allowGlobalConfirmation

# Install .NET Framework 4.8 Developer Pack (needed for legacy .NET apps)
RUN choco install netfx-4.8-devpack -y

# Install additional build tools for legacy .NET apps
RUN choco install git -y `
    && choco install nuget.commandline -y `
    && choco install visualstudio2019buildtools -y `
    && choco install visualstudio2019-workload-manageddesktop -y `
    && choco install visualstudio2019-workload-netweb -y

WORKDIR /build
