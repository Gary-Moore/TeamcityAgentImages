#!/bin/bash
set -e

# Default values
IMAGE_NAME="teamcity-agent"
TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
BASE_IMAGE="jetbrains/teamcity-agent:2025.03-linux-sudo"
REGISTRY_NAME="youracrname"  
VERBOSE=0
# Collect additional --build-arg options
BUILD_ARGS=()


show_help() {
    echo ""
    echo "🛠  ACR Cloud Build Script"
    echo "--------------------------"
    echo "Usage: ./build-image.sh [-n image-name] [-t tag] [-f dockerfile-path] [-c build-context] [-r acr-name] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -n   Image name         (default: $IMAGE_NAME)"
    echo "  -t   Image tag          (default: $TAG)"
    echo "  -f   Dockerfile path    (default: $DOCKERFILE)"
    echo "  -c   Build context path (default: $BUILD_CONTEXT)"
    echo "  -b   Base image         (default: $BASE_IMAGE)"
    echo "  -r   ACR registry name  (default: $REGISTRY_NAME)"
    echo "  --build-arg ARG         Add build argument"
    echo "  --verbose               Print full az acr build command"
    echo "  -h                      Show help message"
    echo ""
}



if [ $# -eq 0 ]; then show_help; exit 1; fi
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n) IMAGE_NAME="$2"; shift ;;
        -t) TAG="$2"; shift ;;
        -f) DOCKERFILE="$2"; shift ;;
        -c) BUILD_CONTEXT="$2"; shift ;;
        -b) BASE_IMAGE="$2"; shift ;;
        -r) REGISTRY_NAME="$2"; shift ;;
        --build-arg) BUILD_ARGS+=("--build-arg" "$2"); shift ;;
        --verbose) VERBOSE=1 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Check for the version file
if [ ! -f VERSION.txt ]; then
    echo "❌ VERSION.txt not found. Please run the version generation script first."
    exit 1
fi


VERSION=$(cat VERSION.txt)
DOCKERFILE_PATH="$(realpath "$DOCKERFILE")"
BUILD_CONTEXT_PATH="$(realpath "$BUILD_CONTEXT")"
IMAGE_FULL_NAME="$REGISTRY_NAME.azurecr.io/$IMAGE_NAME:$TAG"



echo "🛠  Submitting build to Azure Container Registry..."
echo "    Registry    : $REGISTRY_NAME"
echo "    Image       : $IMAGE_FULL_NAME"
echo "    Dockerfile  : $DOCKERFILE_PATH"
echo "    Context     : $BUILD_CONTEXT_PATH"
echo "    Base Image  : $BASE_IMAGE"
echo "    Version     : $VERSION"

if [ "$VERBOSE" -eq 1 ]; then
    echo ""
    echo "Running the following ACR build command:"
    echo "az acr build --registry $REGISTRY_NAME --image $IMAGE_NAME:$TAG --file \"$DOCKERFILE_PATH\" ${BUILD_ARGS[*]} --build-arg BASE_IMAGE=$BASE_IMAGE --build-arg VERSION=$VERSION \"$BUILD_CONTEXT_PATH\""
    echo ""
fi


az acr build \
    --registry "$REGISTRY_NAME" \
    --image "$IMAGE_NAME:$TAG" \
    --file "$DOCKERFILE_PATH" \
    "${BUILD_ARGS[@]}" \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg VERSION="$VERSION" \
    "$BUILD_CONTEXT_PATH"

echo "✅ ACR build submitted successfully: $IMAGE_FULL_NAME"

