#!/usr/bin/env bash
# Install (or upgrade) every KOpenWallpaper Plasma wallpaper plugin found in
# plugins/* for the current user. Re-run after editing any plugin.
#
# Usage:
#   ./install.sh            # install/upgrade all plugins
#   ./install.sh video gif  # only the named plugins
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TYPE="Plasma/Wallpaper"

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
    targets=()
    for d in "$SCRIPT_DIR"/plugins/*/; do
        [ -f "$d/metadata.json" ] && targets+=("$(basename "$d")")
    done
fi

for name in "${targets[@]}"; do
    pkg="$SCRIPT_DIR/plugins/$name"
    if [ ! -f "$pkg/metadata.json" ]; then
        echo "!! skipping '$name' — no plugins/$name/metadata.json"
        continue
    fi
    # The shader plugin ships GLSL sources; compile them to .qsb before install.
    if [ "$name" = "shader" ]; then
        "$SCRIPT_DIR/compile-shaders.sh"
    fi
    id="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['KPlugin']['Id'])" "$pkg/metadata.json")"
    if kpackagetool6 --type "$TYPE" --show "$id" >/dev/null 2>&1; then
        echo ">> Upgrading $id"
        kpackagetool6 --type "$TYPE" --upgrade "$pkg"
    else
        echo ">> Installing $id"
        kpackagetool6 --type "$TYPE" --install "$pkg"
    fi
done

echo
echo "Done. To apply changes to a running session, restart plasmashell:"
echo "    kquitapp6 plasmashell && (plasmashell &)   # or just log out/in"
echo
echo "Then: right-click desktop → Configure Desktop and Wallpaper →"
echo "      Wallpaper Type → pick a \"KOpenWallpaper (…)\" entry."
