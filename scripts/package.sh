#!/bin/zsh
# Builds pokove in Release and zips it for a GitHub release: build/pokove.zip.
# The site's download button points at releases/latest/download/pokove.zip.
#   scripts/package.sh [notes.md]
# With the release notes, it also adds the release to the site's appcast (scripts/appcast.py),
# which is how installed copies hear about it.
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
if [[ $# -ge 1 ]]; then scripts/appcast.py "$1"; fi
echo "Publish it with:"
echo "  gh release create v$VERSION build/pokove.zip --title \"pokove $VERSION\" --notes-file ${1:-<notes.md>}"
echo "then commit and push site/public/appcast.xml once the release is up."
