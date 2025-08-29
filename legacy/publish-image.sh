#!/bin/bash

set -euo pipefail

# Default values
IMAGE_NAME="teamcity-agent"
TAG="latest"
VERBOSE=0
TAG_LATEST=false
TAG_STANDARD=false

show_help() {
    echo ""
    echo "🚀  Docker Publish Script"
    echo "------------------------"
    echo "Usage: ./publish-image.sh [-n image-name] [-t tag] [--tag-latest] [--tag-standard] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -n   Image name         (default: $IMAGE_NAME)"
    echo "  -t   Image tag          (default: $TAG)"
    echo "  --tag-latest            Also tag and push the image as 'latest'"
    echo "  --tag-standard          Also tag and push the image as 'standard'"
    echo "  --verbose               Print detailed output"
    echo "  -h                      Show help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n) IMAGE_NAME="$2"; shift ;;
        -t) TAG="$2"; shift ;;
        --tag-latest) TAG_LATEST=true ;;
        --tag-standard) TAG_STANDARD=true ;;
        --verbose) VERBOSE=1 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

FULL_TAG="${IMAGE_NAME}:${TAG}"

# Show verbose output if requested
if [[ "$VERBOSE" -eq 1 ]]; then
    echo "📤 Publishing Docker image:"
    echo "  Image Name : $IMAGE_NAME"
    echo "  Image Tag  : $TAG"
    echo "  Full Tag   : $FULL_TAG"
    echo ""
fi

# Push the image with the provided tag
if ! docker push "$FULL_TAG"; then
    echo "❌ Error: Failed to push image: $FULL_TAG"
    exit 1
fi

# Tag and push additional tags if requested
if [[ "$TAG_LATEST" == "true" ]]; then
    docker tag "$FULL_TAG" "${IMAGE_NAME}:latest"
    if ! docker push "${IMAGE_NAME}:latest"; then
        echo "❌ Error: Failed to push tag: latest"
        exit 1
    fi
    [[ "$VERBOSE" -eq 1 ]] && echo "Also pushed tag: latest"
fi

if [[ "$TAG_STANDARD" == "true" ]]; then
    docker tag "$FULL_TAG" "${IMAGE_NAME}:standard"
    if ! docker push "${IMAGE_NAME}:standard"; then
        echo "❌ Error: Failed to push tag: standard"
        exit 1
    fi
    [[ "$VERBOSE" -eq 1 ]] && echo "Also pushed tag: standard"
fi

# Get image digest
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$FULL_TAG" 2>/dev/null || true)

if [[ -n "$DIGEST" ]]; then
    echo "Digest: $DIGEST"
else
    echo "⚠️ Warning: Unable to retrieve image digest from local inspect."
fi

