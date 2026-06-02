#!/usr/bin/env bash
# Compile GLSL fragment shaders to Qt6 .qsb bundles.
#
#   ./compile-shaders.sh                 # compile all bundled plugins/shader shaders
#   ./compile-shaders.sh path/to/foo.frag [more.frag …]   # compile specific files
#
# Each input "foo.frag" produces "foo.frag.qsb" next to it. Custom shaders must
# use the same std140 'buf' uniform block as the bundled ones (qt_Matrix,
# qt_Opacity, iTime, iResolution).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate qsb (not always on PATH).
QSB="$(command -v qsb6 || command -v qsb || true)"
for cand in /usr/lib/qt6/bin/qsb /usr/lib/x86_64-linux-gnu/qt6/bin/qsb; do
    [ -z "$QSB" ] && [ -x "$cand" ] && QSB="$cand"
done
if [ -z "$QSB" ]; then
    echo "!! qsb not found — install qt6-shadertools" >&2
    exit 1
fi

# Multi-target set: SPIR-V (Vulkan) + GLSL (GL/GLES) + HLSL + MSL, so the
# wallpaper works regardless of the RHI backend Plasma picks.
TARGETS=(--glsl "100es,120,150,300es,330,440" --hlsl 50 --msl 12 -O)

inputs=("$@")
if [ ${#inputs[@]} -eq 0 ]; then
    mapfile -t inputs < <(find "$SCRIPT_DIR/plugins/shader/contents/shaders" \( -name '*.frag' -o -name '*.vert' \) 2>/dev/null)
fi

for f in "${inputs[@]}"; do
    out="${f}.qsb"
    echo ">> $QSB -> $out"
    "$QSB" "${TARGETS[@]}" -o "$out" "$f"
done
echo "Done (${#inputs[@]} shader(s))."
