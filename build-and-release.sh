#!/bin/bash

# Elite Scholar APK Build and Release Script
# Usage: ./build-and-release.sh v1.0.2

set -e

VERSION=$1
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
DEPLOY_SERVER="elitescholar.ng"  # Your domain
DEPLOY_USER="elitesc1"  # Your cPanel username

if [ -z "$VERSION" ]; then
  echo "Usage: ./build-and-release.sh v1.0.2"
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable not set"
  echo "Set it with: export GITHUB_TOKEN=your_token"
  exit 1
fi

# Validate version format and sane limits (max v9.9.99.99)
VERSION_NO_V=${VERSION#v}
IFS='.' read -r V1 V2 V3 V4 <<< "$VERSION_NO_V"
if ! [[ "$V1" =~ ^[0-9]+$ && "$V2" =~ ^[0-9]+$ && "$V3" =~ ^[0-9]+$ && "$V4" =~ ^[0-9]+$ ]]; then
  echo "❌ Invalid version format. Expected: vMAJOR.MINOR.PATCH.BUILD (e.g. v1.0.1.11)"
  exit 1
fi
if [ "$V1" -gt 9 ] || [ "$V2" -gt 99 ] || [ "$V3" -gt 99 ] || [ "$V4" -gt 99 ]; then
  echo "❌ Version $VERSION exceeds allowed limits (max v9.99.99.99)"
  exit 1
fi

echo "🚀 Building Elite Scholar $VERSION..."

# Navigate to source
cd /Users/apple/Downloads/apps/elite/elscholar-ui

# Update version in appUpdater.ts and APKDownload.tsx
echo "📝 Updating version..."
# Convert version to integer code (e.g., v1.0.6.1 → 1006001)
VERSION_CODE=$(echo $VERSION_NO_V | awk -F. '{printf "%d%02d%03d", $1, $2, ($3*100 + $4)}')
sed -i '' "s/const CURRENT_VERSION = '.*'/const CURRENT_VERSION = '${VERSION_NO_V}'/" src/utils/appUpdater.ts
sed -i '' "s/const CURRENT_VERSION_CODE = .*/const CURRENT_VERSION_CODE = $VERSION_CODE;/" src/utils/appUpdater.ts
sed -i '' "s/const CURRENT_VERSION = '.*'/const CURRENT_VERSION = '${VERSION_NO_V}'/" src/core/components/APKDownload.tsx
sed -i '' "s/const CURRENT_VERSION_CODE = .*/const CURRENT_VERSION_CODE = $VERSION_CODE;/" src/core/components/APKDownload.tsx

# Update service worker cache version
echo "🔄 Updating service worker cache version..."
sed -i '' "s/const CACHE_NAME = 'elite-scholar-v.*'/const CACHE_NAME = 'elite-scholar-v${VERSION#v}'/" public/sw.js

# Build web app
echo "🔨 Building web app..."
npm run build

# Push dist to web-dist repo
echo "🌐 Pushing dist to web-dist repo..."
WEB_DIST_DIR="/Users/apple/Downloads/apps/elite/web-dist"

if [ ! -d "$WEB_DIST_DIR/.git" ]; then
  rm -rf "$WEB_DIST_DIR"
  mkdir -p "$WEB_DIST_DIR"
  cd "$WEB_DIST_DIR"
  git init
  git remote add origin https://github.com/eliteedtech1-debug/web-dist.git
else
  cd "$WEB_DIST_DIR"
fi

rm -rf *
cp -r /Users/apple/Downloads/apps/elite/elscholar-ui/dist/* .
git add -A
git commit -m "Build $VERSION"
git push -f https://${GITHUB_TOKEN}@github.com/eliteedtech1-debug/web-dist.git main

echo "✅ Dist pushed to GitHub. Pull in cPanel to deploy."

# Return to UI directory for Android build
cd /Users/apple/Downloads/apps/elite/elscholar-ui

# Sync to Android
echo "📱 Syncing to Android..."
npx cap sync android

# Regenerate icons if logo exists
if [ -f "src/assets/img/logo.png" ]; then
  echo "Regenerating app icons..."
  cordova-res android --skip-config --copy || echo "⚠️ Icon generation failed (continuing...)"
fi

# Build APK
echo "🤖 Building Android APK..."
cd android
./gradlew clean assembleRelease

# Copy APK
echo "📦 Copying APK..."
cp app/build/outputs/apk/release/app-release.apk ~/Desktop/EliteScholar-$VERSION.apk
cd ..

# Update releases repo
echo "📤 Updating releases repo..."
cd /Users/apple/Downloads/apps/elite/elitescholar-releases
cp ~/Desktop/EliteScholar-$VERSION.apk EliteScholar.apk

# Update version.json
cat > version.json << EOF
{
  "version": "${VERSION#v}",
  "versionCode": $VERSION_CODE,
  "apkUrl": "https://github.com/eliteedtech1-debug/elitescholar.app/releases/latest/download/EliteScholar.apk",
  "releaseNotes": "Release $VERSION",
  "forceUpdate": false
}
EOF

# Commit and push
git add EliteScholar.apk version.json
git commit -m "Release $VERSION"
git push https://${GITHUB_TOKEN}@github.com/eliteedtech1-debug/elitescholar.app.git main

# Create GitHub release
echo "🎉 Creating GitHub release..."
export GH_TOKEN=$GITHUB_TOKEN
gh release create $VERSION EliteScholar.apk \
  --repo eliteedtech1-debug/elitescholar.app \
  --title "Elite Scholar $VERSION" \
  --notes "Automated release build $VERSION

Download and install EliteScholar.apk on your Android device.

**What's New:**
- Bug fixes and improvements
- Updated to version ${VERSION#v}

**Installation:**
1. Download EliteScholar.apk
2. Enable 'Install from unknown sources' in device settings
3. Open APK file to install"

# Send push notification to all apps
echo "📢 Sending update notification to all users..."
curl -X POST "https://server.brainstorm.ng/elite-apiv2/api/push-notifications/broadcast" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -d "{
    \"title\": \"📱 New Version Available!\",
    \"body\": \"Elite Scholar ${VERSION#v} is now available with improvements and bug fixes. Tap to update!\",
    \"data\": {
      \"type\": \"app_update\",
      \"version\": \"${VERSION#v}\",
      \"apkUrl\": \"https://github.com/eliteedtech1-debug/elitescholar.app/releases/latest/download/EliteScholar.apk\"
    }
  }" || echo "⚠️ Push notification failed (continuing...)"

echo ""
echo "✅ Release $VERSION published successfully!"
echo "🌐 Frontend deployed to https://elitescholar.ng"
echo "📱 APK: https://github.com/eliteedtech1-debug/elitescholar.app/releases/latest/download/EliteScholar.apk"
echo ""
echo "🎯 Users will get auto-update notification!"
