#!/usr/bin/env python3
"""Adds the release in build/pokove.zip to the site's Sparkle appcast (site/public/appcast.xml).

    scripts/appcast.py <notes.md>

Run it after scripts/package.sh, and push the appcast only once the GitHub release holds the zip:
the new item points at releases/download/v<version>/pokove.zip. The zip is signed with the EdDSA
key in this Mac's login keychain (Sparkle's generate_keys made it; the app checks it against
SUPublicEDKey in Config/Info.plist).

The notes file is the release notes: Korean bullets, a "---" line, then English bullets. Lines that
don't start with "- " are left out of the appcast.
"""
import email.utils
import html
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/DerivedData/Build/Products/Release/pokove.app"
ZIP = ROOT / "build/pokove.zip"
APPCAST = ROOT / "site/public/appcast.xml"
SIGN = ROOT / "build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
DOWNLOAD = "https://github.com/geonhwiii/pokove/releases/download/v{version}/pokove.zip"
KEEP = 10


def bullets(block: str) -> str:
    items = [line[2:].strip() for line in block.splitlines() if line.startswith("- ")]
    return "<ul>" + "".join(f"<li>{html.escape(item)}</li>" for item in items) + "</ul>"


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    korean, _, english = Path(sys.argv[1]).read_text().partition("\n---\n")
    info = plistlib.loads((APP / "Contents/Info.plist").read_bytes())
    version, build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    minimum = info.get("LSMinimumSystemVersion", "15.0")
    signature = subprocess.run([str(SIGN), str(ZIP)], check=True, capture_output=True, text=True).stdout.strip()
    if "edSignature=" not in signature:
        sys.exit(f"sign_update gave no signature: {signature}")

    item = f"""    <item>
      <title>pokove {version}</title>
      <pubDate>{email.utils.formatdate(localtime=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{minimum}</sparkle:minimumSystemVersion>
      <description xml:lang="ko"><![CDATA[{bullets(korean)}]]></description>
      <description xml:lang="en"><![CDATA[{bullets(english)}]]></description>
      <enclosure url="{DOWNLOAD.format(version=version)}" type="application/octet-stream" {signature}/>
    </item>"""

    old = APPCAST.read_text() if APPCAST.exists() else ""
    # Newest first; a rerun for the same version replaces its item.
    items = [block for block in re.findall(r"    <item>.*?</item>", old, re.S)
             if f"<sparkle:shortVersionString>{version}<" not in block]
    items = [item] + items[: KEEP - 1]
    body = "\n".join(items)
    APPCAST.write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>pokove</title>
    <link>https://pokove.vercel.app/appcast.xml</link>
    <language>ko</language>
{body}
  </channel>
</rss>
""")
    print(f"Added pokove {version} ({build}) to {APPCAST.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
