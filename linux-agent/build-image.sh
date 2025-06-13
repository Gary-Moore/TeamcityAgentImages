#!/bin/bash
set -e

# Default values
IMAGE_NAME="teamcity-agent"
TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="."
BASE_IMAGE="jetbrains/teamcity-agent:2025.03-linux-sudo"
VERBOSE=0

show_help() {
    echo ""
    echo "🛠  Docker Build Script"
    echo "------------------------"
    echo "Usage: ./build-image.sh [-n image-name] [-t tag] [-f dockerfile-path] [-c build-context] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -n   Image name         (default: $IMAGE_NAME)"
    echo "  -t   Image tag          (default: $TAG)"
    echo "  -f   Dockerfile path    (default: $DOCKERFILE)"
    echo "  -c   Build context path (default: $BUILD_CONTEXT)"
    echo "  -b   Base image         (default: $BASE_IMAGE)"
    echo "  --verbose               Print full docker command"
    echo "  -h                      Show help message"
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
        --verbose) VERBOSE=1 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker to proceed."
    exit 1
fi

# Check for the version file
if [ ! -f VERSION.txt ]; then
    echo "❌ VERSION.txt not found. Please run the version generation script first."
    exit 1
fi

# Read the version from VERSION.txt
VERSION=$(cat VERSION.txt)

# Real paths for Dockerfile and Build Context
DOCKERFILE_PATH="$(realpath "$DOCKERFILE")"
BUILD_CONTEXT_PATH="$(realpath "$BUILD_CONTEXT")"

# Echo version and build information  
echo "🛠  Building Docker image..."
echo "    Image Name : $IMAGE_NAME"
echo "    Tag        : $TAG"
echo "    Dockerfile : $DOCKERFILE_PATH"
echo "    Context    : $BUILD_CONTEXT_PATH"
echo "    Base Image : $BASE_IMAGE"
echo "    Version    : $VERSION"

# Verbose mode: print the full command to be run
if [ "$VERBOSE" -eq 1 ]; then
    echo ""
    echo "Running the following Docker command:"
    echo "docker build -f \"$DOCKERFILE_PATH\" --build-arg BASE_IMAGE=$BASE_IMAGE -t \"$IMAGE_NAME:$TAG\" --label \"org.opencontainers.image.version=$VERSION\" \"$BUILD_CONTEXT_PATH\""
    echo ""
fi

# Build the Docker image with the version label
if docker build -f "$DOCKERFILE_PATH" --build-arg BASE_IMAGE=$BASE_IMAGE -t "$IMAGE_NAME:$TAG" --label "org.opencontainers.image.version=$VERSION" "$BUILD_CONTEXT_PATH"; then
    echo "✅ Build completed successfully: $IMAGE_NAME:$TAG"
else
    echo "❌ Build failed."
    exit 1
fi