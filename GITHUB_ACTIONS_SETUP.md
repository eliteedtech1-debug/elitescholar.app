# GitHub Actions Setup for Auto APK Build

## Required GitHub Secrets

Go to: https://github.com/eliteedtech1-debug/elitescholar.app/settings/secrets/actions

Add these secrets:

### 1. PRIVATE_REPO_TOKEN
Personal Access Token with `repo` scope to access your private source code repo.

**Create token:**
1. Go to: https://github.com/settings/tokens/new
2. Name: `APK Build Token`
3. Expiration: No expiration (or 1 year)
4. Scopes: Check `repo` (full control of private repositories)
5. Click "Generate token"
6. Copy the token (starts with `ghp_`)
7. Add to GitHub Secrets as `PRIVATE_REPO_TOKEN`

### 2. KEYSTORE_BASE64
Your Android keystore file encoded in base64.

**Generate:**
```bash
cd /Users/apple/Downloads/apps/elite/elscholar-ui/android
base64 -i elite-release.keystore | pbcopy
```
Then paste into GitHub Secrets as `KEYSTORE_BASE64`

### 3. KEYSTORE_PASSWORD
Value: `elite123`

### 4. KEY_PASSWORD
Value: `elite123`

## How to Use

### Option 1: Create a Git Tag (Recommended)
```bash
cd /Users/apple/Downloads/apps/elite/elitescholar-ui
git tag v1.0.2
git push origin v1.0.2
```

This will automatically:
1. Build the web app
2. Build Android APK
3. Sign the APK
4. Create a GitHub release
5. Upload the APK

### Option 2: Manual Trigger
1. Go to: https://github.com/eliteedtech1-debug/elitescholar.app/actions
2. Click "Build Android APK"
3. Click "Run workflow"
4. Select branch and click "Run workflow"

## Workflow

```
Push tag (v1.0.2)
    ↓
GitHub Actions starts
    ↓
Checkout private source code
    ↓
Build web app (npm run build)
    ↓
Sync to Android (npx cap sync)
    ↓
Build APK (gradlew assembleRelease)
    ↓
Sign APK (apksigner)
    ↓
Create GitHub Release
    ↓
Upload EliteScholar.apk
    ↓
Done! ✅
```

## Update version.json

After release, update version.json:
```bash
cd /Users/apple/Downloads/apps/elite/elitescholar-releases
# Edit version.json with new version
git add version.json
git commit -m "Update to v1.0.2"
git push
```

## Notes

- Builds take ~5-10 minutes
- APK is automatically signed with your keystore
- Release is created automatically
- Users get auto-update notification
