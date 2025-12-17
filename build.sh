#!/bin/bash

set -e

APP_NAME="SSH Baddie"
VERSION="1.0.0"

echo "🚀 Building and packaging ${APP_NAME}..."

# Step 1: Build the Go backend
echo "1️⃣  Building Go backend..."


echo "Building Go backend for macOS..."

cd ./ssh-backend

# Build for macOS (Intel)
GOOS=darwin GOARCH=amd64 go build -o ./build/ssh-backend-amd64 .

# Build for macOS (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o ./build/ssh-backend-arm64 .

cd ..

# Create universal binary
lipo -create \
  ./ssh-backend/build/ssh-backend-amd64 \
  ./ssh-backend/build/ssh-backend-arm64 \
  -output ./ssh-backend/build/ssh-backend

# Clean up individual binaries
rm ./ssh-backend/build/ssh-backend-amd64
rm ./ssh-backend/build/ssh-backend-arm64

# Make executable
chmod +x ./ssh-backend/build/ssh-backend

echo "✅ Backend built successfully at assets/ssh-backend"

# Step 2: Build Flutter app
echo "2️⃣  Building Flutter app..."
flutter clean
flutter build macos --release

# Step 3: Copy backend to app bundle
echo "3️⃣  Bundling backend..."
mkdir -p "build/macos/Build/Products/Release/${APP_NAME}.app/Contents/Resources"
cp ./ssh-backend/build/ssh-backend \
   "build/macos/Build/Products/Release/${APP_NAME}.app/Contents/Resources/"
chmod +x "build/macos/Build/Products/Release/${APP_NAME}.app/Contents/Resources/ssh-backend"
