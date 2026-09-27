#!/bin/zsh
# Builds pokove in Release and zips it for a GitHub release: build/pokove.zip.
# The site's download button points at releases/latest/download/pokove.zip.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building Release…"
xcodebuild -project pokove.xcodeproj -scheme pokove -configuration Release \
  -derivedDataPath build/DerivedData build -quiet

APP="build/DerivedData/Build/Products/Release/pokove.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
rm -f build/pokove.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" build/pokove.zip

echo "Wrote build/pokove.zip (version $VERSION)"
echo "Publish it with:"
echo "  gh release create v$VERSION build/pokove.zip --title \"pokove $VERSION\""
