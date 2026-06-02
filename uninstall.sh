#!/usr/bin/env bash
# Remove every KOpenWallpaper Plasma wallpaper plugin for the current user.
set -euo pipefail
TYPE="Plasma/Wallpaper"

IDS=(
    com.github.kopenwalpaper.video
    com.github.kopenwalpaper.gif
    com.github.kopenwalpaper.shader
    com.github.kopenwalpaper.web
    com.github.kopenwalpaper   # legacy id from v0.1
)

for id in "${IDS[@]}"; do
    if kpackagetool6 --type "$TYPE" --show "$id" >/dev/null 2>&1; then
        echo ">> Removing $id"
        kpackagetool6 --type "$TYPE" --remove "$id"
    fi
done
echo "Done. Restart plasmashell or log out/in to fully unload."
