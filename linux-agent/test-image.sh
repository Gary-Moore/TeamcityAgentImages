#!/bin/bash

# Default values
IMAGE_NAME="teamcity-agent-dotnet8-node20"
TAG="latest"
TEST_COMMAND=""
VERBOSE=0

# Show help message
show_help() {
    echo ""
    echo "Docker Image Test Script"
    echo "-----------------------------"
    echo "Usage: ./test-image.sh [-n image-name] [-t tag] [-c test-command] [--verbose]"
    echo ""
    echo "Options:"
    echo "  -n   Docker image name (default: $IMAGE_NAME)"
    echo "  -t   Image tag (default: $TAG)"
    echo "  -c   Test command to run inside the container (default: .NET and Node.js version checks)"
    echo "  --verbose        Enable verbose output"
    echo "  -h               Show help message"
    echo ""
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -n) IMAGE_NAME="$2"; shift ;;
        -t) TAG="$2"; shift ;;
        -c) TEST_COMMAND="$2"; shift ;;
        --verbose) VERBOSE=1 ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

FULL_IMAGE="$IMAGE_NAME:$TAG"

# Use default test command if none provided
if [ -z "$TEST_COMMAND" ]; then
    TEST_COMMAND="dotnet --version && node --version"
fi

# Show verbose output if requested
echo "🧪 Testing Docker image: $FULL_IMAGE"
if [ "$VERBOSE" -eq 1 ]; then
    echo "🔍 Test command: $TEST_COMMAND"
    echo "📦 Running container..."
fi

# Run the test command inside the container
docker run --rm "$FULL_IMAGE" /bin/bash -c "$TEST_COMMAND"

# Check the result of the test
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo "✅ Test passed: Image $FULL_IMAGE is functional."
    exit 0
else
    echo "❌ Test failed: Image $FULL_IMAGE did not run successfully."
    exit 1
fi
