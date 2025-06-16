
# TeamCity Custom Docker Build Agents

This repository contains custom TeamCity build agent images for Windows and Linux, along with supporting scripts for building and publishing these images to an Azure Container Registry (ACR). These images are designed to be used as TeamCity agents in our CI/CD pipeline.

## 🚀 Build and Publish Workflow

Each agent has its own build process. The build scripts will:

1. **Authenticate with Azure Container Registry (ACR)** using your ACR credentials.
2. Build the **TeamCity agent** Docker image.
3. Tag the image according to the **OS, .NET SDK version, and Node.js version**.
4. Push the image to **ACR**.

### Authenticating to Azure Container Registry (ACR)

Before building or pushing any images, ensure you are authenticated to Azure Container Registry.

#### Local Development

For interactive local use, run:

```bash
az acr login --name myacr
```

Replace `myacr` with your Azure Container Registry name.

#### CI/CD (TeamCity)

In CI pipelines (e.g., TeamCity), authentication is performed using a **service principal**. Set the following TeamCity environment variables (marked as hidden/secure):

- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_TENANT_ID`

Then use the following login command in a build step before pushing to ACR:

```bash
az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID"

az acr login --name myacr
```

These credentials should be stored securely as TeamCity environment variables:

* `AZURE_CLIENT_ID`

* `AZURE_CLIENT_SECRET`

* `AZURE_TENANT_ID`


The build process requires a version number to tag the image. This version is automatically generated from your Git tags and stored in the `VERSION.txt` file.

### To generate the `VERSION.txt` file:

```bash
./scripts/generate-version.sh
```

The build script will fail if `VERSION.txt` is missing.

### TeamCity Tip

In TeamCity, run `generate-version.sh` as a build step before `build-image.sh`. As a fallback, you may use `%build.vcs.number%` or date-based tags.

## Image Testing

Use the provided script to validate that your built image contains the correct tools.

### Default Check (e.g., .NET and Node.js):

```bash
./test-image.sh -n teamcity-agent-dotnet8-node20 -t latest
```

### Custom Check (e.g., Terraform agent):

```bash
./test-image.sh -n teamcity-terraform-agent -t latest -c "terraform version"
```

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

- Docker must be installed on the build machine or agent.
- Azure CLI must be installed (`az`) for authentication.
- A valid Azure login or service principal must be configured.
- `VERSION.txt` must be generated before running `build-image.sh`.

## Troubleshooting

### ACR Login Fails with `az login` Required

Ensure you're authenticated with Azure:

- Use `az login` locally
- Use `az login --service-principal` in CI

### "Docker: Cannot connect to the daemon"

Ensure:
- Docker is running on the agent host
- The `buildagent` user is in the `docker` group
- The agent has access to `/var/run/docker.sock`