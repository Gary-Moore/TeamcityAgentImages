
# TeamCity Build Template Example

This document provides an example TeamCity build template for building, testing, and publishing Docker images to Azure Container Registry (ACR).

## Build Steps

### Build Step 1: Authenticate to Docker Registry
- **Type**: Command Line
- **Custom Script**:
    ```bash
    docker login %env.ACR_LOGIN_SERVER% -u %env.ACR_USERNAME% -p %env.ACR_PASSWORD%
    ```

### Build Step 2: Generate Version File
- **Type**: Command Line
- **Custom Script**:
    ```bash
    ./scripts/generate-version.sh
    ```

### Build Step 3: Build Docker Image
- **Type**: Command Line
- **Custom Script**:
    ```bash
    ./scripts/build-image.sh
    ```

### Build Step 4: Test Docker Image
- **Type**: Command Line
- **Custom Script**:
    ```bash
    ./scripts/test-image.sh
    ```

### Build Step 5: Publish Docker Image
- **Type**: Command Line
- **Custom Script**:
    ```bash
    ./scripts/publish-image.sh -n %env.IMAGE_NAME% -t %env.IMAGE_TAG% --tag-latest --verbose
    ```

## Artifact Paths
- `image-info.txt`
