#!/bin/zsh
# Builds pokove in Release and installs it to ~/Applications (or a path you pass), then relaunches it.
#   scripts/install.sh               -> ~/Applications/pokove.app
#   scripts/install.sh /Applications -> /Applications/pokove.app
set -euo pipefail

cd "$(dirname "$0")/.."
DEST_DIR="${1:-$HOME/Applications}"

echo "Building Release…"
xcodebuild -project pokove.xcodeproj -scheme pokove -configuration Release \
  -derivedDataPath build/DerivedData build -quiet

APP="build/DerivedData/Build/Products/Release/pokove.app"
mkdir -p "$DEST_DIR"

# Only one notch app should run at a time (dancove was its old name).
pkill -x pokove 2>/dev/null || true
pkill -x dancove 2>/dev/null || true
sleep 0.5

rm -rf "$DEST_DIR/pokove.app"
cp -R "$APP" "$DEST_DIR/"
open "$DEST_DIR/pokove.app"
echo "Installed and launched $DEST_DIR/pokove.app"
