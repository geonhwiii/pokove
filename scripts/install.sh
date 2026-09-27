#!/bin/zsh
# Builds dancove in Release and installs it to ~/Applications (or a path you pass), then relaunches it.
#   scripts/install.sh               -> ~/Applications/dancove.app
#   scripts/install.sh /Applications -> /Applications/dancove.app
set -euo pipefail

cd "$(dirname "$0")/.."
DEST_DIR="${1:-$HOME/Applications}"

echo "Building Release…"
xcodebuild -project dancove.xcodeproj -scheme dancove -configuration Release \
  -derivedDataPath build/DerivedData build -quiet

APP="build/DerivedData/Build/Products/Release/dancove.app"
mkdir -p "$DEST_DIR"

# Only one notch app should run at a time.
pkill -x dancove 2>/dev/null || true
sleep 0.5

rm -rf "$DEST_DIR/dancove.app"
cp -R "$APP" "$DEST_DIR/"
open "$DEST_DIR/dancove.app"
echo "Installed and launched $DEST_DIR/dancove.app"
