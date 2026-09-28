# dmgbuild settings for build/pokove.dmg (scripts/make-dmg.py passes app and background).
# The window matches Config/dmg-background.png (600×400, from scripts/make-dmg-background.swift):
# the app on the left, Applications on the right, the arrow between them, the three balls below.
import os.path

app = defines["app"]
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents/Resources/AppIcon.icns")
background = defines["background"]

format = "UDZO"
window_rect = ((200, 160), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

icon_size = 112
text_size = 13
icon_locations = {
    "pokove.app": (150, 168),
    "Applications": (450, 168),
}
