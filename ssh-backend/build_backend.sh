#!/bin/bash
# build_backend.sh

set -e

echo "Building Go backend for macOS..."

# Create Resources directory if it doesn't exist
mkdir -p "../ssh-baddie-frontend/macos/Runner/Resources"

# Build for macOS (Intel)
GOOS=darwin GOARCH=amd64 go build -o ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend-amd64 .

# Build for macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend-arm64 .

# Create universal binary
lipo -create \
  ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend-amd64 \
  ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend-arm64 \
  -output ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend

# Clean up individual binaries
rm ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend-amd64
rm ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend-arm64

# Make executable
chmod +x ../ssh-baddie-frontend/macos/Runner/Resources/ssh-backend

echo "✅ Backend built successfully at macos/Runner/Resources/ssh-backend"