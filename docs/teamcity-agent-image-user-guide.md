
# 🐳 Internal Dev Guide: Building CI/CD Agent Images

## Welcome
This document explains how our team builds, tests, and publishes custom TeamCity CI/CD agent images using a portable, parameterised shell-based pipeline.

---

## 💼 Repository Structure
The structure of the repository is designed for portability and clarity. Here is an overview:

- **`common/`**: Common resources used across agents.
  - `scripts/`: Contains shell scripts for versioning and other utilities.
- **`docs/`**: Documentation for developers and the project.
  - `teamcity-agent-image-user-guide.md`: Onboarding guide for new contributors to this project.
  - `project-structure.md`: Explanation of the repository layout.
  - `index.md`: General overview of the project.
  - `teamcity-template-example.md`: Example TeamCity templates.
- **`linux-agent/`**: Resources for Linux-based TeamCity build agents.
  - `build-image.sh`: Builds the image.
  - `test-image.sh`: Validates the image.
  - `publish-image.sh`: Tags and pushes the image.
  - `.env.example`: Example environment variable file for Linux agents.
  - `dotnetagent.dockerfile`: Dockerfile for the .NET agent image.
- **`windows-agent/`**: Resources for Windows-based TeamCity build agents.
  - Similar to the Linux agent structure but adapted for Windows-specific needs.

---

## 🔐 Authentication
Before publishing, always include a separate build step:
```bash
docker login %env.ACR_LOGIN_SERVER% -u %env.ACR_USERNAME% -p %env.ACR_PASSWORD%
```
Ensure your credentials are securely stored in TeamCity's environment variables or any other secure configuration source.

---

## 🔧🐧 Linux-based Dotnet Agent Image CI Pipeline (TeamCity)

This pipeline is used to build, test, and publish Linux-based .NET agent images. It’s designed to be run in a TeamCity CI pipeline and is parameterized to allow for flexibility in versioning, Docker login, and publishing.

| Step | Script |
|------|--------|
| Step 1 | docker login |
| Step 2 | ./scripts/generate-version.sh (Ensure VERSION.txt is created before proceeding) |
| Step 3 | ./build-image.sh |
| Step 4 | ./test-image.sh |
| Step 5 | ./publish-image.sh |

### Notes:
- **Authentication step**: docker login must always be the first step to authenticate against the Docker registry. This is crucial to ensure that the images are pushed to the right registry. Skipping this will cause the build steps to fail. This is particularly important for working in different environments (e.g., local, staging, production).
- **Versioning step**: Ensure that the `VERSION.txt` file is generated before starting the build process by running `./scripts/generate-version.sh`. This file is used to tag the image with a version number. This step ensures consistency in versioning across the CI pipeline. You can manually check or adjust the version in the VERSION.txt file if needed, but the script ensures that the image is tagged accordingly.
- **Linux-based .NET image**: This pipeline is specifically for building Linux-based .NET agent images. Make sure that the scripts and Dockerfile are properly configured for Linux environments, which might differ from other platforms (like Windows).
- **Debugging tip**: In case of a failure, check the build logs in TeamCity to ensure that all environment variables are correctly set and the pipeline is executing in the right sequence.

---

## 🏷 Tagging Strategy
- `:YYYY-MM-DD` → Automatic per build
- `:latest` → Tag with `--tag-latest`
- `:standard` → Promote a build with `--tag-standard`
- `:dotnet-8.0-node-20` → Tag with a specific .NET version and Node.js version (e.g., dotnet-8.0-node-20) for backwards compatibility or project-specific needs.
- `:dotnet-10.0-node-24` → Tag with a specific .NET version and Node.js version for projects migrating to newer versions.

### Notes:
- The `dotnet-8.0-node-20` tag can be used to maintain older agent images for projects still on .NET 8.0 or other specific versions, ensuring compatibility across different pipelines.
- Multiple versions (e.g., dotnet-8.0-node-20 and dotnet-10.0-node-20) can be tagged accordingly, allowing teams to maintain parallel versions of agent images for different projects.

---

## Artifact Output
- `image-info.txt` includes image name, tag, and digest
- Mark it as a TeamCity build artifact for traceability.

### Notes:
- **Artifact traceability**: Ensure `image-info.txt` is included in the build artifacts so it can be retrieved during deployments or troubleshooting.
- The `image-info.txt` file should be checked for correct image details (tag and digest) after each successful build.

---

### Versioning the Image

The build process requires a version number to tag the image. This version is automatically generated from your Git tags and stored in the `VERSION.txt` file.

To generate the `version.txt` file:

1. **Generate Version File:**

```bash
./scripts/generate-version.sh
```

This script will create a VERSION.txt file that contains the latest version based on your Git tags or commit number.

2. **Ensure Version.txt is present before building:**

The build-image.sh script will check for the existence of VERSION.txt. If it's missing, the build will fail. Ensure that you run the version generation script before attempting to build the image.

In addition to the basic version tags, you can also choose to tag the images with specific versions of .NET and Node.js (e.g., dotnet-8.0-node-20) for more granular control over the versions of the agent.

---

## Local Testing

For Windows-based development machines, you can use a `.env` file and PowerShell to test scripts locally:

1. **Set environment variables from the `.env.example` file**:
   - Open the `.env.example` file and manually set each environment variable in PowerShell:
     ```powershell
     $env:IMAGE_NAME = "myacr.azurecr.io/teamcity-agent"
     $env:TAG = "latest"
     $env:DOCKER_USERNAME = "your-docker-username"
     $env:DOCKER_PASSWORD = "your-docker-password"
     ```

2. **Generate the version file**:
   - Before starting the build, ensure that the `VERSION.txt` file is created. Run the following script:
     ```powershell
     ./scripts/generate-version.sh
     ```

3. **Run the build, test, and publish scripts**:
   ```powershell
   ./build-image.sh
   ./test-image.sh
   ./publish-image.sh --tag-latest

### Notes:
- Make sure Docker is installed and running on your Windows machine.
- These steps assume you have Docker for Windows configured to use Linux containers.
- Ensure that the .env file includes the necessary environment variables like `IMAGE_NAME`, `TAG`, `DOCKER_USERNAME`, and `DOCKER_PASSWORD` for local testing.
- Ensure the VERSION.txt file is generated by running ./scripts/generate-version.sh before starting the build.

---

## 💡 Gotchas
- `docker login` must occur in a separate CI step.
- Scripts assume Docker CLI is installed and the user is logged in.
- TeamCity's Docker Registry UI credential config doesn’t apply to shell steps.

### Additional Gotchas:
- **Secure Credentials**: Ensure that all credentials (e.g., ACR username and password) are stored securely, using environment variables or TeamCity's secure storage features.
- **Cross-platform compatibility**: Scripts should be POSIX-compliant and tested across environments (e.g., Linux and Windows) to ensure portability.

---

## 📝 Changelog Usage
This project uses a `CHANGELOG.md` file to track major updates and shared understanding between developers. You don't need to log every line change — just the impactful ones:
- Script or tag behaviour changes
- Image build conventions
- Versioning scheme updates
- Anything affecting usage or deployment

Use Git for the fine-grained details. Use the changelog for team clarity.

### Notes:
- Follow a clear template for changelog entries (e.g., “Added feature X” or “Fixed bug Y”) to maintain consistency.
- Changelog entries should focus on high-level updates, such as changes in build logic, versioning, or deployment processes.

---

## 👨‍💻 Contributions
- Ensure that all changes are portable across Linux and Windows environments and comply with POSIX standards to maintain compatibility..
- Update `CHANGELOG.md` and tag new versions.
- Test locally before making changes to the CI pipeline.

### Additional Contribution Guidelines:
- All contributions should be tested both locally and in CI before pushing changes.
- Ensure that any new feature or fix maintains compatibility across platforms (Windows/Linux).
