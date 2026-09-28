#!/bin/zsh
# Builds pokove in Release for a GitHub release: build/pokove.dmg for people, build/pokove.zip for
# in-app updates. The site's download button points at releases/latest/download/pokove.dmg.
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

# The download people get by hand: the app beside Applications over the starters' table, to drag
# it across (scripts/make-dmg.py). In-app updates keep using the zip.
if [[ ! -x build/dmgbuild-venv/bin/python ]]; then
  /usr/bin/python3 -m venv build/dmgbuild-venv
  build/dmgbuild-venv/bin/pip install -q "dmgbuild==1.6.4"
fi
rm -f build/pokove.dmg
build/dmgbuild-venv/bin/python scripts/make-dmg.py "$APP" build/pokove.dmg

echo "Wrote build/pokove.zip and build/pokove.dmg (version $VERSION)"
if [[ $# -ge 1 ]]; then scripts/appcast.py "$1"; fi
echo "Publish it with:"
echo "  gh release create v$VERSION build/pokove.dmg build/pokove.zip --title \"pokove $VERSION\" --notes-file ${1:-<notes.md>}"
echo "then commit and push site/public/appcast.xml once the release is up."
