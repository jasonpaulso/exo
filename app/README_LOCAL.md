# Local macOS App Build Guide

Quick reference for building and packaging the EXO macOS app locally.

## Prerequisites

```bash
# One-time setup
brew install macmon
xcode-select -s /Applications/Xcode.app/Contents/Developer

# Store notarization credentials (one-time)
xcrun notarytool store-credentials "EXO-notarization" \
  --apple-id "YOUR_EMAIL" \
  --team-id "5PDMD78Q2H"
```

## Quick Build (Development)

For rapid iteration without signing/notarization:

```bash
# 1. Build dashboard (if changed)
cd dashboard && npm run build && cd ..

# 2. Build PyInstaller bundle
uv run pyinstaller packaging/pyinstaller/exo.spec

# 3. Build Swift app
cd app/EXO && xcodebuild build -scheme EXO -configuration Release -derivedDataPath build && cd ../..

# 4. Inject runtime
rm -rf app/EXO/build/Build/Products/Release/EXO.app/Contents/Resources/exo
cp -R dist/exo app/EXO/build/Build/Products/Release/EXO.app/Contents/Resources/exo

# 5. Run
open app/EXO/build/Build/Products/Release/EXO.app
```

### One-liner (after dashboard is built)

```bash
uv run pyinstaller packaging/pyinstaller/exo.spec && \
cd app/EXO && xcodebuild build -scheme EXO -configuration Release -derivedDataPath build && cd ../.. && \
rm -rf app/EXO/build/Build/Products/Release/EXO.app/Contents/Resources/exo && \
cp -R dist/exo app/EXO/build/Build/Products/Release/EXO.app/Contents/Resources/exo && \
open app/EXO/build/Build/Products/Release/EXO.app
```

## Full Build (Distribution)

Creates a signed, notarized DMG for distribution.

```bash
# 1. Build everything
cd dashboard && npm run build && cd ..
uv run pyinstaller packaging/pyinstaller/exo.spec
cd app/EXO && xcodebuild build -scheme EXO -configuration Release -derivedDataPath build && cd ../..

# 2. Prepare output directory
mkdir -p output/dmg-root
cp -R app/EXO/build/Build/Products/Release/EXO.app output/dmg-root/
rm -rf output/dmg-root/EXO.app/Contents/Resources/exo
cp -R dist/exo output/dmg-root/EXO.app/Contents/Resources/exo
ln -sf /Applications output/dmg-root/Applications

# 3. Sign everything
SIGNING_IDENTITY="Developer ID Application: Jason Southwell (5PDMD78Q2H)"

# Sign PyInstaller binaries
find output/dmg-root/EXO.app/Contents/Resources/exo -type f \( -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 | \
  while IFS= read -r -d '' file; do
    /usr/bin/codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$file" 2>/dev/null || true
  done

# Sign app bundle
/usr/bin/codesign --deep --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" output/dmg-root/EXO.app

# 4. Create and sign DMG
hdiutil create -volname "EXO" -srcfolder output/dmg-root -ov -format UDZO output/EXO.dmg
/usr/bin/codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" output/EXO.dmg

# 5. Notarize and staple
xcrun notarytool submit output/EXO.dmg --keychain-profile "EXO-notarization" --wait
xcrun stapler staple output/EXO.dmg
```

## Build Locations

| Artifact | Path |
|----------|------|
| PyInstaller bundle | `dist/exo/` |
| Swift app | `app/EXO/build/Build/Products/Release/EXO.app` |
| Dashboard | `dashboard/build/` |
| Final DMG | `output/EXO.dmg` |

## Troubleshooting

### xcodebuild: command line tools error
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Code signing identity not found
```bash
security find-identity -v -p codesigning
```
Ensure "Developer ID Application" certificate has a private key (check Keychain Access → My Certificates).

### Notarization fails
Check the log:
```bash
xcrun notarytool log <SUBMISSION_ID> --keychain-profile "EXO-notarization"
```

## Debug Build

For faster iteration with debug symbols:
```bash
cd app/EXO && xcodebuild build -scheme EXO -configuration Debug -derivedDataPath build && cd ../..
# App at: app/EXO/build/Build/Products/Debug/EXO.app
```
