#!/usr/bin/env python3
"""Builds the disk image people download: build/pokove.dmg, laid out by Config/dmg-settings.py over
Config/dmg-background.png.

    build/dmgbuild-venv/bin/python scripts/make-dmg.py <pokove.app> <output.dmg>

scripts/package.sh runs it with dmgbuild (1.6.4, the last for this Mac's Python 3.9) from a venv in
build/. dmgbuild reads hdiutil's output and its errors as one stream, and hdiutil now ends its plist
with a deprecation warning on stderr, so hdiutil is run here with the two kept apart.
"""
import plistlib
import subprocess
import sys
from pathlib import Path

import dmgbuild
import dmgbuild.core

ROOT = Path(__file__).resolve().parent.parent


def hdiutil(cmd, *args, **kwargs):
    plist = kwargs.get("plist", True)
    result = subprocess.run(["/usr/bin/hdiutil", cmd, *args, *(["-plist"] if plist else [])], capture_output=True)
    if plist:
        return result.returncode, plistlib.loads(result.stdout) if result.stdout.strip() else {}
    return result.returncode, (result.stdout + result.stderr).decode()


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    dmgbuild.core.hdiutil = hdiutil
    dmgbuild.build_dmg(
        sys.argv[2], "pokove",
        settings_file=str(ROOT / "Config/dmg-settings.py"),
        defines={"app": sys.argv[1], "background": str(ROOT / "Config/dmg-background.png")},
    )


if __name__ == "__main__":
    main()
