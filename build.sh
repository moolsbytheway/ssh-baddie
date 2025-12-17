#!/bin/bash

set -e

APP_NAME="SSH Baddie"
APP_PATH="build/macos/Build/Products/Release/${APP_NAME}.app"

# Your Developer ID - find with: security find-identity -v -p codesigning
DEVELOPER_ID="Developer ID Application: Moulaye Abderrahmane Eli Mbitaleb (UC5F79548R)"

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
mkdir -p "${APP_PATH}/Contents/Resources"
cp ./ssh-backend/build/ssh-backend "${APP_PATH}/Contents/Resources/"
chmod +x "${APP_PATH}/Contents/Resources/ssh-backend"

# Step 4: Sign the backend binary first
echo "4️⃣  Signing backend binary..."
codesign --force --options runtime --sign "${DEVELOPER_ID}" \
  "${APP_PATH}/Contents/Resources/ssh-backend"

# Step 5: Re-sign the entire app
echo "5️⃣  Signing app bundle..."
codesign --force --deep --options runtime --sign "${DEVELOPER_ID}" \
  "${APP_PATH}"

# Step 6: Verify signature
echo "6️⃣  Verifying signature..."
codesign --verify --verbose "${APP_PATH}"

echo "✅ Build complete: ${APP_PATH}"