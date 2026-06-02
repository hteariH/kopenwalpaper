#!/usr/bin/env python3
"""
import-we — apply a Wallpaper Engine project as a KOpenWallpaper wallpaper.

A Wallpaper Engine project is a folder with a project.json describing its
`type` and main `file`. This maps the supported types onto the matching
KOpenWallpaper plugin:

    video  (mp4/webm/…)  -> com.github.kopenwalpaper.video
    web    (index.html)  -> com.github.kopenwalpaper.web
    gif                  -> com.github.kopenwalpaper.gif

Scene wallpapers (scene.pkg) and application wallpapers are proprietary /
executable and are NOT supported — they're detected and skipped.

Usage:
    ./import-we.py <project-folder | project.json | workshop-id> [--print]

    --print   show what would be applied instead of applying it
"""
import json
import os
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

WE_APPID = "431960"  # Wallpaper Engine Steam app id
WORKSHOP_BASES = [
    "~/.steam/steam/steamapps/workshop/content",
    "~/.local/share/Steam/steamapps/workshop/content",
    "~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/workshop/content",
]

VIDEO_EXT = {".mp4", ".webm", ".mkv", ".ogv", ".mov", ".m4v"}
WEB_EXT = {".html", ".htm"}
GIF_EXT = {".gif", ".apng", ".webp", ".png"}

PLUGINS = {
    "video": ("com.github.kopenwalpaper.video", "VideoUrl"),
    "web": ("com.github.kopenwalpaper.web", "PageUrl"),
    "gif": ("com.github.kopenwalpaper.gif", "ImageUrl"),
}


def die(msg, code=1):
    sys.stderr.write("import-we: " + msg + "\n")
    sys.exit(code)


def resolve_project(arg):
    """Return the project folder for a path or a bare workshop id."""
    p = Path(arg).expanduser()
    if p.is_file() and p.name == "project.json":
        return p.parent
    if p.is_dir() and (p / "project.json").is_file():
        return p
    if arg.isdigit():  # workshop id
        for base in WORKSHOP_BASES:
            cand = Path(base).expanduser() / WE_APPID / arg
            if (cand / "project.json").is_file():
                return cand
    die(f"no project.json found for '{arg}'")


def classify(project, folder):
    """Return (our_type, main_file_path) or (None, reason)."""
    wtype = str(project.get("type", "")).lower().strip()
    file = project.get("file", "")

    if wtype in ("scene",) or file.endswith(".pkg") or (folder / "scene.pkg").exists():
        return None, "scene wallpapers (scene.pkg) are not supported"
    if wtype in ("application", "executable"):
        return None, "application wallpapers are not supported"

    # Trust the main file's extension when present (most reliable).
    ext = Path(file).suffix.lower() if file else ""
    if ext in VIDEO_EXT or wtype == "video":
        return "video", file
    if ext in WEB_EXT or wtype == "web":
        return "web", file or "index.html"
    if ext in GIF_EXT:
        return "gif", file
    if not file:
        return None, f"project.json has no usable 'file' (type='{wtype}')"
    return None, f"unsupported type '{wtype}' / file '{file}'"


def file_url(path: Path):
    return "file://" + quote(str(path))


def apply(plugin, key, url, title):
    js = (
        "var ds = desktops();"
        "for (var i = 0; i < ds.length; i++) { var d = ds[i];"
        f"  d.wallpaperPlugin = '{plugin}';"
        f"  d.currentConfigGroup = ['Wallpaper', '{plugin}', 'General'];"
        f"  d.writeConfig('{key}', '{url}');"
        "  d.reloadConfig(); }"
        f"print('applied {plugin}');"
    )
    subprocess.run(
        ["qdbus6", "org.kde.plasmashell", "/PlasmaShell",
         "org.kde.PlasmaShell.evaluateScript", js],
        check=True,
    )
    print(f">> Applied '{title}' as {plugin}\n   {key} = {url}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--print" in sys.argv[1:]
    if not args:
        die(__doc__.strip(), 2)

    folder = resolve_project(args[0])
    project = json.loads((folder / "project.json").read_text(encoding="utf-8", errors="replace"))
    title = project.get("title", folder.name)

    our_type, info = classify(project, folder)
    if our_type is None:
        die(f"'{title}': {info}")

    main_file = folder / info
    if not main_file.is_file():
        die(f"'{title}': main file not found: {main_file}")

    plugin, key = PLUGINS[our_type]
    url = file_url(main_file)

    if dry:
        print(f"{title}\n  type   : {our_type}\n  plugin : {plugin}\n  {key} : {url}")
        return
    apply(plugin, key, url, title)


if __name__ == "__main__":
    main()
