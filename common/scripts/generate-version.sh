#!/bin/bash
set -e

VERSION=$(git describe --tags --always)
echo "$VERSION" > VERSION.txt
echo "Version generated: $VERSION"
