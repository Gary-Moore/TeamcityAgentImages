
# TeamCity Custom Docker Build Agents

This repository contains custom TeamCity build agent images for Windows and Linux, along with supporting scripts for building and publishing these images to an Azure Container Registry (ACR). These images are designed to be used as TeamCity agents in our CI/CD pipeline.

## 🚀 Build and Publish Workflow

Each agent has its own build process. The build scripts will:

1. **Authenticate with Azure Container Registry (ACR)** using your ACR credentials.
2. Build the **TeamCity agent** Docker image.
3. Tag the image according to the **OS, .NET SDK version, and Node.js version**.
4. Push the image to **ACR**.

### Authenticating to Azure Container Registry (ACR)

Before building or pushing any images, ensure that you are authenticated to Azure Container Registry. If you're working with a private registry, you'll need to log in using the following command:

```bash
az acr login --name myacr
```

Replace `myacr` with your Azure Container Registry name.

If you don't have the Azure CLI installed, follow the [official installation guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) to install it.

### Versioning the Image

The build process requires a version number to tag the image. This version is automatically generated from your Git tags and stored in the `VERSION.txt` file.

To generate the `version.txt` file:

1. **Generate Version File:**

```bash
./scripts/generate-version.sh
```

This script will create a `VERSION.txt` file that contains the latest version based on your Git tags or commit number.

2. **Ensure Version.txt is present before building**:

The `build-image.sh` script will check for the existence of `VERSION.txt`. If it's missing, the build will fail. Ensure that you run the version generation script before attempting to build the image.

 🐋 Agent Image Publishing Strategy

### Overview
All TeamCity custom agent images are tagged using the following standard scheme:

| Tag                  | Purpose                                                            |
|----------------------|--------------------------------------------------------------------|
| `YYYY-MM-DD` or VCS number | Every build gets a unique tag based on the date or VCS commit ID for auditability. |
| `latest`             | Automatically assigned to the most recent image built (weekly or on commit). |
| `standard`           | Manually promoted tag representing a stable, recommended image version. |
| `dotnet-8.0-node-20` | A specific version of the image built with .NET 8.0 and Node.js 20. Useful for backwards compatibility in certain pipelines. |
| `dotnet-10.0-node-20` | A specific version built with .NET 10.0 and Node.js 20. For projects migrating to the latest version. |

### Publishing Process

| Step                | Description                                                     |
|---------------------|-----------------------------------------------------------------|
| `build-image.sh`     | Builds the agent image locally.                                 |
| `test-image.sh`      | Runs basic validation tests on the image.                       |
| `publish-image.sh`   | Pushes the image to Azure Container Registry (ACR) and applies optional tags. |

## TeamCity Build Parameters

| Parameter           | Example                             | Notes                               |
|---------------------|-------------------------------------|-------------------------------------|
| `env.IMAGE_NAME`    | `myacr.azurecr.io/teamcity-agent-dockercli` | Full image name                     |
| `env.IMAGE_TAG`     | `2025-03-25` or `%build.vcs.number%` | Image version, e.g., date or VCS ID |
| `env.TAG_LATEST`    | `true`                              | Pushes `:latest` tag if set         |
| `env.TAG_STANDARD`  | `true`                              | Pushes `:standard` tag if set       |

## Example Publishing Command
```bash
./scripts/publish-image.sh -n %env.IMAGE_NAME% -t %env.IMAGE_TAG% --tag-latest --verbose

# Set --tag-standard only when promoting a known-good image.
```

## Prerequisites

* Docker must be installed on the system to build and test images.
* You must be authenticated to Azure Container Registry (ACR) to push images.
* Ensure TeamCity is properly configured to use the built images.
* **Generate the `VERSION.txt` file** before building: `./scripts/generate-version.sh`
